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
    enum State {
        case analyzing
        case done(MenuResult)
        case failed(String)
    }

    private(set) var state: State = .analyzing
    private let sourceImage: UIImage
    private let makeAnalyzer: () -> MenuAnalyzer
    private var hasStarted = false

    init(image: UIImage, makeAnalyzer: @escaping () -> MenuAnalyzer = AppSettings.makeAnalyzer) {
        self.sourceImage = image
        self.makeAnalyzer = makeAnalyzer
    }

    /// Runs the analysis once; later calls (view re-appearing) do nothing.
    func start() async {
        guard !hasStarted else { return }
        hasStarted = true
        await run()
    }

    func retry() async {
        await run()
    }

    private func run() async {
        state = .analyzing
        let source = sourceImage
        let analyzer = makeAnalyzer()
        do {
            let result = try await Task.detached(priority: .userInitiated) {
                try await Self.analyze(source, with: analyzer)
            }.value
            state = .done(result)
        } catch is CancellationError {
            state = .failed("ยกเลิกแล้ว")
        } catch {
            state = .failed(
                (error as? LocalizedError)?.errorDescription ?? error.localizedDescription)
        }
    }

    nonisolated private static func analyze(
        _ source: UIImage, with analyzer: MenuAnalyzer
    ) async throws -> MenuResult {
        let page = ImageCropper.normalized(source, maxLongEdge: ImageCropper.workingLongEdge)
        guard let jpeg = ImageCropper.uploadJPEG(from: page) else {
            throw MenuAnalyzerError.invalidResponse("could not encode the photo")
        }
        guard let analysis = try await analyzer.analyze([jpeg]).first else {
            throw MenuAnalyzerError.invalidResponse("no result for this page")
        }
        let items = analysis.dishes.map { dish in
            DishItem(dish: dish, photo: dish.photoBBox.flatMap { ImageCropper.crop(page, to: $0) })
        }
        return MenuResult(pageImage: page, items: items, notes: analysis.notesTH)
    }
}
