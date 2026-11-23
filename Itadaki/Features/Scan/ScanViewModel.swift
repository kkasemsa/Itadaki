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

@MainActor
@Observable
final class ScanViewModel {
    enum Phase: Equatable {
        /// The photo is too small to read; waiting for the user to retake or insist.
        case tooSmall
        case analyzing
        case done
        case failed(String)
    }

    /// Photos with a long edge below this are almost never legible.
    static let minimumLongEdge: CGFloat = 900
    static let maxConcurrentRequests = 3

    private(set) var phase: Phase = .analyzing
    /// Dishes read so far. Fills in strip by strip while `phase` is `.analyzing`.
    private(set) var result: MenuResult?
    private(set) var completedParts = 0
    private(set) var totalParts = 1
    /// True while re-reading, one effort level up, a page whose first read found nothing.
    private(set) var isSecondAttempt = false
    /// Strips that failed while others succeeded.
    private(set) var failedParts = 0

    let sourcePixelSize: CGSize
    private let sourceImage: UIImage
    private let makeAnalyzer: (AnalysisEffort) -> MenuAnalyzer
    private let strips: Int
    private let effort: AnalysisEffort
    private var hasStarted = false
    private var photoCache: [UUID: UIImage] = [:]

    init(
        image: UIImage,
        strips: Int = AppSettings.strips,
        effort: AnalysisEffort = AppSettings.effort,
        makeAnalyzer: @escaping (AnalysisEffort) -> MenuAnalyzer = AppSettings.makeAnalyzer
    ) {
        self.effort = effort
        self.sourceImage = image
        self.strips = strips
        self.makeAnalyzer = makeAnalyzer
        self.sourcePixelSize = CGSize(
            width: image.size.width * image.scale, height: image.size.height * image.scale)
    }

    /// Runs the analysis once; later calls (view re-appearing) do nothing.
    func start() async {
        guard !hasStarted else { return }
        hasStarted = true
        if max(sourcePixelSize.width, sourcePixelSize.height) < Self.minimumLongEdge {
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

    private func run() async {
        phase = .analyzing
        result = nil
        completedParts = 0
        failedParts = 0
        isSecondAttempt = false
        photoCache = [:]

        let source = sourceImage
        let strips = strips
        guard
            let prepared = await Task.detached(priority: .userInitiated, operation: {
                Self.prepare(source, strips: strips)
            }).value
        else {
            phase = .failed("เตรียมรูปไม่สำเร็จ ลองถ่ายใหม่")
            return
        }
        totalParts = prepared.requests.count

        var outcome = await readAll(prepared, effort: effort)
        if outcome.error == nil, outcome.analysis.dishes.isEmpty, let harder = effort.harder {
            // The first read found nothing: try once more, one effort level up.
            isSecondAttempt = true
            completedParts = 0
            outcome = await readAll(prepared, effort: harder)
        }

        if let error = outcome.error, outcome.succeeded == 0 {
            phase = .failed(Self.message(for: error))
            return
        }
        failedParts = prepared.requests.count - outcome.succeeded
        publish(outcome.analysis, page: prepared.page)
        phase = .done
    }

    /// Sends every strip (at most three at a time), publishing dishes as each returns.
    private func readAll(
        _ prepared: Prepared, effort: AnalysisEffort
    ) async -> (analysis: PageAnalysis, succeeded: Int, error: Error?) {
        let analyzer = makeAnalyzer(effort)
        var parts = [PageAnalysis?](repeating: nil, count: prepared.requests.count)
        var firstError: Error?

        func merged() -> PageAnalysis {
            TilePlan.merge(
                parts.enumerated().compactMap { index, analysis in
                    analysis.map { (prepared.tiles[index], $0) }
                })
        }

        await withTaskGroup(of: (Int, Result<PageAnalysis, Error>).self) { group in
            var next = 0
            func addNext() {
                let index = next
                next += 1
                let request = prepared.requests[index]
                group.addTask {
                    do {
                        guard let page = try await analyzer.analyze([request]).first else {
                            throw MenuAnalyzerError.invalidResponse("no result for this part")
                        }
                        return (index, .success(page))
                    } catch {
                        return (index, .failure(error))
                    }
                }
            }
            for _ in 0..<min(Self.maxConcurrentRequests, prepared.requests.count) { addNext() }
            while let (index, outcome) = await group.next() {
                completedParts += 1
                switch outcome {
                case .success(let page):
                    parts[index] = page
                    publish(merged(), page: prepared.page)
                case .failure(let error):
                    if firstError == nil { firstError = error }
                }
                if next < prepared.requests.count { addNext() }
            }
        }
        return (merged(), parts.compactMap { $0 }.count, firstError)
    }

    private func publish(_ analysis: PageAnalysis, page: UIImage) {
        let items = analysis.dishes.map { dish -> DishItem in
            if photoCache[dish.id] == nil, let box = dish.photoBBox {
                photoCache[dish.id] = ImageCropper.crop(page, to: box)
            }
            return DishItem(dish: dish, photo: photoCache[dish.id])
        }
        result = MenuResult(pageImage: page, items: items, notes: analysis.notesTH)
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
