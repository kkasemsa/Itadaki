import Observation
import UIKit

/// A dish plus the photo cropped for it from the menu page, if any.
struct DishItem: Identifiable {
    let dish: Dish
    let photo: UIImage?
    var id: UUID { dish.id }
}

/// Everything the menu screen needs for one analyzed page.
struct MenuResult {
    let pageImage: UIImage
    let items: [DishItem]
    let notes: String
}

/// One photographed menu page and how far its reading has got.
struct PageState: Identifiable {
    enum Status: Equatable {
        case reading
        case done
        case failed(String)
    }

    let id: Int
    /// The page upright and at working size.
    var image: UIImage
    /// Dishes read so far; fills in strip by strip while `status` is `.reading`.
    var result: MenuResult?
    var status: Status = .reading
    /// Strips that failed while others on this page succeeded.
    var failedParts = 0

    var dishCount: Int { result?.items.count ?? 0 }
}

@MainActor
@Observable
final class ScanViewModel {
    enum Phase: Equatable {
        /// A single photo too small to read; waiting for the user to retake or insist.
        case tooSmall
        case analyzing
        case done
        /// Every page failed.
        case failed(String)
    }

    /// Photos with a long edge below this are almost never legible.
    static let minimumLongEdge: CGFloat = 900
    static let maxConcurrentRequests = 3
    /// Most pages one scan accepts; each page is held in memory at working size.
    static let maximumPages = 8

    private(set) var phase: Phase = .analyzing
    private(set) var pages: [PageState] = []
    private(set) var completedParts = 0
    private(set) var totalParts = 1
    /// True while re-reading, one effort level up, pages whose first read found nothing.
    private(set) var isSecondAttempt = false

    let sourceImages: [UIImage]
    private let makeAnalyzer: (AnalysisEffort) -> MenuAnalyzer
    private let strips: Int
    private let effort: AnalysisEffort
    private var hasStarted = false
    private var photoCache: [UUID: UIImage] = [:]

    init(
        images: [UIImage],
        strips: Int = AppSettings.strips,
        effort: AnalysisEffort = AppSettings.effort,
        makeAnalyzer: @escaping (AnalysisEffort) -> MenuAnalyzer = AppSettings.makeAnalyzer
    ) {
        self.sourceImages = Array(images.prefix(Self.maximumPages))
        self.strips = strips
        self.effort = effort
        self.makeAnalyzer = makeAnalyzer
    }

    /// Dishes from every page, in page order. The order summary is built from these.
    var allDishes: [Dish] {
        pages.flatMap { $0.result?.items.map(\.dish) ?? [] }
    }

    /// Pixel size of the first photo, for the too-small message.
    var firstPixelSize: CGSize {
        guard let image = sourceImages.first else { return .zero }
        return CGSize(width: image.size.width * image.scale, height: image.size.height * image.scale)
    }

    /// Runs the analysis once; later calls (view re-appearing) do nothing.
    func start() async {
        guard !hasStarted else { return }
        hasStarted = true
        let size = firstPixelSize
        if sourceImages.count == 1, max(size.width, size.height) < Self.minimumLongEdge {
            phase = .tooSmall
        } else {
            await run()
        }
    }

    /// Analyze again, e.g. after an error or when the user insists on a small photo.
    func retry() async {
        await run()
    }

    // MARK: Pipeline

    private struct Prepared: @unchecked Sendable {
        let page: UIImage
        let tiles: [NormalizedRect]
        let requests: [PageRequest]
    }

    /// One request to send: strip `tile` of page `page`.
    private struct Job: Hashable {
        let page: Int
        let tile: Int
    }

    private func run() async {
        phase = .analyzing
        pages = []
        completedParts = 0
        isSecondAttempt = false
        photoCache = [:]

        let sources = sourceImages
        let strips = strips
        let prepared = await Task.detached(priority: .userInitiated) {
            sources.compactMap { Self.prepare($0, strips: strips) }
        }.value
        guard !prepared.isEmpty else {
            phase = .failed("เตรียมรูปไม่สำเร็จ ลองถ่ายใหม่")
            return
        }
        pages = prepared.enumerated().map { PageState(id: $0.offset, image: $0.element.page) }

        var parts = prepared.map { [PageAnalysis?](repeating: nil, count: $0.requests.count) }
        var errors = [Error?](repeating: nil, count: prepared.count)
        let allJobs = prepared.enumerated().flatMap { page, item in
            item.requests.indices.map { Job(page: page, tile: $0) }
        }

        totalParts = allJobs.count
        await read(allJobs, prepared: prepared, effort: effort, parts: &parts, errors: &errors)

        // Pages whose first read came back empty get one more try, one level up.
        if let harder = effort.harder {
            let emptyPages = prepared.indices.filter { page in
                errors[page] == nil && merged(parts[page], prepared[page]).dishes.isEmpty
            }
            if !emptyPages.isEmpty {
                isSecondAttempt = true
                let jobs = allJobs.filter { emptyPages.contains($0.page) }
                completedParts = 0
                totalParts = jobs.count
                for page in emptyPages { pages[page].status = .reading }
                await read(jobs, prepared: prepared, effort: harder, parts: &parts, errors: &errors)
            }
        }

        for page in prepared.indices {
            let succeeded = parts[page].compactMap { $0 }.count
            if succeeded == 0, let error = errors[page] {
                pages[page].status = .failed(Self.message(for: error))
            } else {
                pages[page].failedParts = parts[page].count - succeeded
                pages[page].status = .done
            }
        }
        let failures = pages.compactMap { page -> String? in
            if case .failed(let message) = page.status { return message }
            return nil
        }
        phase = failures.count == pages.count ? .failed(failures.first ?? "") : .done
    }

    /// Sends the given strips (at most three at a time), publishing each page's dishes
    /// as its strips return.
    private func read(
        _ jobs: [Job], prepared: [Prepared], effort: AnalysisEffort,
        parts: inout [[PageAnalysis?]], errors: inout [Error?]
    ) async {
        let analyzer = makeAnalyzer(effort)
        var remaining = Dictionary(grouping: jobs, by: \.page).mapValues(\.count)

        await withTaskGroup(of: (Job, Result<PageAnalysis, Error>).self) { group in
            var next = 0
            func addNext() {
                let job = jobs[next]
                next += 1
                let request = prepared[job.page].requests[job.tile]
                group.addTask {
                    do {
                        guard let page = try await analyzer.analyze([request]).first else {
                            throw MenuAnalyzerError.invalidResponse("no result for this part")
                        }
                        return (job, .success(page))
                    } catch {
                        return (job, .failure(error))
                    }
                }
            }
            for _ in 0..<min(Self.maxConcurrentRequests, jobs.count) { addNext() }
            while let (job, outcome) = await group.next() {
                completedParts += 1
                switch outcome {
                case .success(let analysis):
                    parts[job.page][job.tile] = analysis
                    publish(merged(parts[job.page], prepared[job.page]), page: job.page)
                case .failure(let error):
                    if errors[job.page] == nil { errors[job.page] = error }
                }
                remaining[job.page, default: 1] -= 1
                if remaining[job.page] == 0, pages[job.page].dishCount > 0 {
                    pages[job.page].status = .done
                }
                if next < jobs.count { addNext() }
            }
        }
    }

    private func merged(_ parts: [PageAnalysis?], _ prepared: Prepared) -> PageAnalysis {
        TilePlan.merge(
            parts.enumerated().compactMap { index, analysis in
                analysis.map { (prepared.tiles[index], $0) }
            })
    }

    private func publish(_ analysis: PageAnalysis, page: Int) {
        let image = pages[page].image
        let items = analysis.dishes.map { dish -> DishItem in
            if photoCache[dish.id] == nil, let box = dish.photoBBox {
                photoCache[dish.id] = ImageCropper.crop(image, to: box)
            }
            return DishItem(dish: dish, photo: photoCache[dish.id])
        }
        pages[page].result = MenuResult(pageImage: image, items: items, notes: analysis.notesTH)
    }

    nonisolated private static func prepare(_ source: UIImage, strips: Int) -> Prepared? {
        let page = ImageCropper.normalized(source, maxLongEdge: ImageCropper.workingLongEdge)
        let tiles = TilePlan.tiles(imageSize: page.size, strips: strips)
        guard let whole = ImageCropper.uploadJPEG(from: page) else { return nil }
        if tiles.count == 1 {
            return Prepared(page: page, tiles: tiles, requests: [PageRequest(image: whole)])
        }
        var requests: [PageRequest] = []
        for tile in tiles {
            guard let strip = ImageCropper.crop(page, to: tile, padding: 0),
                let jpeg = ImageCropper.uploadJPEG(from: strip)
            else { return nil }
            requests.append(PageRequest(image: jpeg, overview: whole))
        }
        return Prepared(page: page, tiles: tiles, requests: requests)
    }

    private static func message(for error: Error) -> String {
        if error is CancellationError { return "ยกเลิกแล้ว" }
        return (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }
}
