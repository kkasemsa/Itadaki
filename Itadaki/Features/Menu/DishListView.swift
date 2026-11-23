import SwiftUI

/// The translated menu: cards grouped under the menu's own headings, a chip bar to
/// jump between headings, and a bar leading to the order summary.
struct DishListView: View {
    let result: MenuResult
    @Binding var order: Order
    /// Status line shown under the list, e.g. while more of the page is being read.
    var progress: String?
    /// Dishes from every page of the scan, so the order can span pages. Defaults to
    /// this page's dishes.
    var allDishes: [Dish]?

    @AppStorage(AppSettings.bahtPer100YenKey) private var bahtPer100Yen = 0.0
    @State private var selected: DishItem?
    @State private var showOrder = false

    private var bahtPerYen: Double { bahtPer100Yen / 100 }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if !result.notes.isEmpty {
                        Label(result.notes, systemImage: "info.circle.fill")
                            .font(.footnote)
                            .foregroundStyle(Theme.ink.opacity(0.75))
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                Theme.accent.opacity(0.08),
                                in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                            )
                            .padding(.bottom, 6)
                    }

                    ForEach(Array(sections.enumerated()), id: \.offset) { index, section in
                        SectionHeader(section: section, fallback: "\(section.items.count) รายการ")
                            .padding(.top, index == 0 ? 2 : 18)
                            .padding(.bottom, 2)
                            .id(index)

                        ForEach(section.items) { item in
                            DishCard(
                                item: item,
                                bahtPerYen: bahtPerYen,
                                showsThumbnail: hasPhotos,
                                quantity: order.quantity(of: item.dish),
                                onAdd: { order.add(item.dish) },
                                onRemove: { order.remove(item.dish) }
                            )
                            .contentShape(RoundedRectangle(cornerRadius: Theme.cardRadius))
                            .onTapGesture { selected = item }
                            .accessibilityAddTraits(.isButton)
                        }
                    }

                    if let progress {
                        Text(progress)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
            }
            .paperBackground()
            .safeAreaInset(edge: .top, spacing: 0) {
                if chipTitles.count > 1 {
                    SectionChips(titles: chipTitles) { index in
                        withAnimation { proxy.scrollTo(index, anchor: .top) }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !order.isEmpty {
                    OrderBar(summary: summary) { showOrder = true }
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.snappy, value: order.isEmpty)
        }
        .sheet(item: $selected) { item in
            DishDetailView(item: item, pageImage: result.pageImage, bahtPerYen: bahtPerYen)
        }
        .sheet(isPresented: $showOrder) {
            OrderSummaryView(summary: summary, bahtPerYen: bahtPerYen, order: $order)
        }
    }

    private var hasPhotos: Bool {
        result.items.contains { $0.photo != nil }
    }

    /// Dishes grouped under the headings printed on the menu, in menu order.
    private var sections: [MenuSection<DishItem>] {
        MenuSection.group(result.items) { $0.dish }
    }

    private var chipTitles: [String] {
        sections.map { $0.titleTH.isEmpty ? ($0.titleJA.isEmpty ? "อื่น ๆ" : $0.titleJA) : $0.titleTH }
    }

    private var summary: OrderSummary {
        order.summary(for: allDishes ?? result.items.map(\.dish))
    }
}

/// Menu heading in Thai with the printed Japanese next to it.
private struct SectionHeader: View {
    let section: MenuSection<DishItem>
    let fallback: String

    var body: some View {
        if section.titleTH.isEmpty && section.titleJA.isEmpty {
            Text(fallback)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(Theme.accent)
                    .frame(width: 4, height: 20)
                    .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 3 }
                Text(section.titleTH.isEmpty ? section.titleJA : section.titleTH)
                    .font(.title2.bold())
                    .foregroundStyle(Theme.ink)
                if !section.titleTH.isEmpty && !section.titleJA.isEmpty {
                    Text(section.titleJA)
                        .font(Theme.mincho(17, relativeTo: .subheadline))
                        .foregroundStyle(Theme.accent)
                        .environment(\.locale, Locale(identifier: "ja"))
                }
                Spacer(minLength: 0)
            }
        }
    }
}

/// Horizontal row of heading chips; tapping one scrolls the list to that heading.
private struct SectionChips: View {
    let titles: [String]
    let onSelect: (Int) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(titles.enumerated()), id: \.offset) { index, title in
                    Button(title) { onSelect(index) }
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 15)
                        .padding(.vertical, 8)
                        .background(Theme.card, in: Capsule())
                        .overlay { Capsule().strokeBorder(Theme.hairline, lineWidth: 1) }
                        .foregroundStyle(Theme.ink)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Theme.paper.opacity(0.94))
        .overlay(alignment: .bottom) { Theme.hairline.frame(height: 1) }
    }
}

/// Floating bar summarising the order; opens the summary to show staff.
private struct OrderBar: View {
    let summary: OrderSummary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text("\(summary.lines.reduce(0) { $0 + $1.quantity })")
                    .font(.subheadline.bold().monospacedDigit())
                    .padding(.horizontal, 9)
                    .padding(.vertical, 3)
                    .background(.white.opacity(0.25), in: Capsule())
                Text("ดูรายการที่จะสั่ง")
                    .font(.headline)
                Spacer()
                Text(PriceFormatter.yen(summary.totalYen))
                    .font(.headline.monospacedDigit())
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .foregroundStyle(.white)
            .background(Theme.accent, in: Capsule())
            .shadow(color: Theme.accent.opacity(0.4), radius: 14, y: 6)
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

#Preview {
    @Previewable @State var order = Order()
    NavigationStack {
        DishListView(result: .preview, order: $order)
            .navigationTitle("เมนู")
            .navigationBarTitleDisplayMode(.inline)
    }
}

extension MenuResult {
    /// Fixture data for previews: a blank page, so no dish has a cropped photo.
    static var preview: MenuResult {
        let analysis = (try? MockMenuAnalyzer.fixturePage()) ?? PageAnalysis(dishes: [])
        let size = CGSize(width: 900, height: 1200)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let page = UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor(red: 0.95, green: 0.92, blue: 0.86, alpha: 1).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            let colors: [UIColor] = [.systemOrange, .systemTeal, .systemBrown]
            for (index, dish) in analysis.dishes.enumerated() {
                guard let box = dish.photoBBox else { continue }
                colors[index % colors.count].setFill()
                context.fill(
                    CGRect(
                        x: box.x * size.width, y: box.y * size.height,
                        width: box.width * size.width, height: box.height * size.height))
            }
        }
        return MenuResult(
            pageImage: page,
            items: analysis.dishes.map { dish in
                DishItem(dish: dish, photo: dish.photoBBox.flatMap { ImageCropper.crop(page, to: $0) })
            },
            notes: analysis.notesTH)
    }
}
