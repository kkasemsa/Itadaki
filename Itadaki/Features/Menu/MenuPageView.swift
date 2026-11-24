import SwiftUI

/// One menu page. On wide screens (iPad, large iPhones in landscape) the original
/// page sits beside the dish list and the two stay in step: tapping a box on the page
/// highlights its dish, and tapping a dish shows where it is printed. On narrow
/// screens it is just the list.
struct MenuPageView: View {
    let result: MenuResult
    @Binding var order: Order
    var progress: String?
    var allDishes: [Dish]?

    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var selection: UUID?

    var body: some View {
        if sizeClass == .regular {
            GeometryReader { proxy in
                HStack(spacing: 0) {
                    pagePane
                    Theme.hairline.frame(width: 1)
                    DishListView(
                        result: result, order: $order, progress: progress, allDishes: allDishes,
                        selection: $selection
                    )
                    .frame(width: min(max(380, proxy.size.width * 0.42), 520))
                }
            }
            .paperBackground()
        } else {
            DishListView(result: result, order: $order, progress: progress, allDishes: allDishes)
        }
    }

    private var pagePane: some View {
        ZoomableImage(
            image: result.pageImage,
            boxes: boxes,
            selection: selection,
            background: UIColor(Theme.paper),
            onSelect: { selection = $0 }
        )
        .overlay(alignment: .bottom) {
            Text(selection == nil ? "แตะกรอบบนเมนูเพื่อดูรายการ" : "ถ่างนิ้วเพื่อซูม แตะสองครั้งเพื่อดูทั้งหน้า")
                .font(.footnote)
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(.black.opacity(0.5), in: Capsule())
                .padding(.bottom, 14)
                .allowsHitTesting(false)
        }
        .clipped()
    }

    private var boxes: [ImageBox] {
        result.items.compactMap { item in
            item.dish.textBBox.map { ImageBox(id: item.dish.id, rect: $0) }
        }
    }
}

#Preview(traits: .landscapeLeft) {
    @Previewable @State var order = Order()
    NavigationStack {
        MenuPageView(result: .preview, order: $order)
            .navigationTitle("เมนู")
            .navigationBarTitleDisplayMode(.inline)
    }
}
