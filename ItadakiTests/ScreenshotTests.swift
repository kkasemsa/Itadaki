#if canImport(UIKit)
import SwiftData
import SwiftUI
import XCTest
@testable import Itadaki

/// Renders the main screens with fixture data and saves them as PNGs, so the design
/// can be reviewed from CI without a device. These tests assert nothing about looks.
@MainActor
final class ScreenshotTests: XCTestCase {
    private let directory = URL(fileURLWithPath: "/tmp/itadaki-snapshots", isDirectory: true)

    /// One fixture for the whole run: `MenuResult.preview` makes new dish ids each call.
    private let preview = MenuResult.preview

    private struct ListHost: View {
        let result: MenuResult
        @State var order: Order
        var body: some View {
            NavigationStack {
                DishListView(result: result, order: $order)
                    .navigationTitle("เมนู")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbarBackground(Theme.paper, for: .navigationBar)
            }
        }
    }

    private var sampleOrder: Order {
        var order = Order()
        let dishes = preview.items.map(\.dish)
        order.add(dishes[0])
        order.add(dishes[3])
        order.add(dishes[3])
        return order
    }

    private var container: ModelContainer!

    func testRenderScreens() async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        container = try ModelContainer(
            for: SavedMenu.self, SavedPage.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let done = PageState(id: 0, image: preview.pageImage, result: preview, status: .done)
        let saved = await HistoryStore.save(pages: [done, done], in: container.mainContext)
        XCTAssertNotNil(saved)
        let reloaded = await HistoryStore.load(try XCTUnwrap(saved))
        XCTAssertEqual(reloaded.count, 2)
        XCTAssertEqual(reloaded[0].result?.items.map(\.dish), preview.items.map(\.dish))
        let dishes = preview.items.map(\.dish)

        for style in [UIUserInterfaceStyle.light, .dark] {
            let suffix = style == .dark ? "-dark" : ""
            try render("1-home" + suffix, style: style, CaptureView())
            try render("2-menu" + suffix, style: style, ListHost(result: preview, order: sampleOrder))
            try render(
                "3-detail" + suffix, style: style,
                DishDetailView(item: preview.items[0], pageImage: preview.pageImage, bahtPerYen: 0.225))
            try render(
                "4-order" + suffix, style: style,
                OrderSummaryView(
                    summary: sampleOrder.summary(for: dishes), bahtPerYen: 0.225,
                    order: .constant(sampleOrder)))
            var pages = (0..<3).map { PageState(id: $0, image: preview.pageImage, result: preview) }
            pages[0].status = .done
            pages[1].status = .reading
            pages[2].status = .failed("")
            try render(
                "8-pages" + suffix, style: style,
                VStack(spacing: 0) {
                    PageStrip(pages: pages, selection: .constant(0))
                    Spacer()
                }
                .paperBackground())
            try render("9-history" + suffix, style: style, NavigationStack { HistoryView() })
            try render("6-settings" + suffix, style: style, SettingsView())
            let tiny = UIGraphicsImageRenderer(size: CGSize(width: 120, height: 80)).image { _ in }
            try render(
                "7-too-small" + suffix, style: style,
                NavigationStack { ScanView(images: [tiny]) })
            try render(
                "5-unreadable" + suffix, style: style,
                NavigationStack {
                    UnreadableView(image: preview.pageImage, notes: "") {}
                })
        }
    }

    private func render<V: View>(_ name: String, style: UIUserInterfaceStyle, _ view: V) throws {
        let frame = CGRect(x: 0, y: 0, width: 393, height: 852)
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        let window = scene.map(UIWindow.init(windowScene:)) ?? UIWindow(frame: frame)
        window.frame = frame
        window.overrideUserInterfaceStyle = style
        window.rootViewController = UIHostingController(
            rootView: view.tint(Theme.accent).modelContainer(container))
        window.makeKeyAndVisible()
        RunLoop.main.run(until: Date().addingTimeInterval(1.0))

        let format = UIGraphicsImageRendererFormat()
        format.scale = 2
        let image = UIGraphicsImageRenderer(bounds: window.bounds, format: format).image { _ in
            window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
        }
        try XCTUnwrap(image.pngData()).write(to: directory.appendingPathComponent(name + ".png"))
        window.isHidden = true
    }
}
#endif
