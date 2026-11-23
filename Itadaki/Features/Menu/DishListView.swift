import SwiftUI

/// The translated menu: cards grouped under the menu's own headings, a chip bar to
/// jump between headings, and a bar leading to the order summary.
struct DishListView: View {
    let result: MenuResult
    @Binding var order: Order
    /// Status line shown under the list, e.g. while more of the page is being read.
    var progress: String?

    @AppStorage(AppSettings.bahtPer100YenKey) private var bahtPer100Yen = 0.0
    @State private var selected: DishItem?
    @State private var showOrder = false

    private var bahtPerYen: Double { bahtPer100Yen / 100 }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if !result.notes.isEmpty {
                        Label(result.notes, systemImage: "info.circle")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.bottom, 4)
                    }

                    ForEach(Array(sections.enumerated()), id: \.offset) { index, section in
                        SectionHeader(section: section, fallback: "\(section.items.count) รายการ")
                            .padding(.top, index == 0 ? 0 : 14)
                            .padding(.horizontal, 4)
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
                            .contentShape(RoundedRectangle(cornerRadius: 20))
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
            .background(Color(.systemGroupedBackground))
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
        order.summary(for: result.items.map(\.dish))
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
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(section.titleTH.isEmpty ? section.titleJA : section.titleTH)
                    .font(.title3.bold())
                if !section.titleTH.isEmpty && !section.titleJA.isEmpty {
                    Text(section.titleJA)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .environment(\.locale, Locale(identifier: "ja"))
                }
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
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(Color(.secondarySystemGroupedBackground), in: Capsule())
                        .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(.bar)
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
            .padding(.vertical, 14)
            .foregroundStyle(.white)
            .background(.tint, in: Capsule())
            .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
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
        let page = UIGraphicsImageRenderer(size: CGSize(width: 600, height: 800)).image { context in
            UIColor.systemGray5.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 600, height: 800))
        }
        let analysis = (try? MockMenuAnalyzer.fixturePage()) ?? PageAnalysis(dishes: [])
        return MenuResult(
            pageImage: page,
            items: analysis.dishes.map { DishItem(dish: $0, photo: nil) },
            notes: analysis.notesTH)
    }
}
