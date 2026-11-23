import SwiftUI

struct DishListView: View {
    let result: MenuResult
    @AppStorage(AppSettings.bahtPerYenKey) private var bahtPerYen = 0.0
    @State private var selected: DishItem?

    var body: some View {
        if result.items.isEmpty {
            ContentUnavailableView(
                "ไม่พบรายการอาหาร",
                systemImage: "text.magnifyingglass",
                description: Text(
                    result.notes.isEmpty ? "ลองถ่ายใหม่ให้ชัดและเห็นเมนูเต็มหน้า" : result.notes)
            )
        } else {
            List {
                if !result.notes.isEmpty {
                    Section {
                        Label(result.notes, systemImage: "info.circle")
                            .font(.callout)
                    }
                }
                ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                    Section {
                        ForEach(section.items) { item in
                            Button {
                                selected = item
                            } label: {
                                DishRow(item: item, bahtPerYen: bahtPerYen, showsThumbnail: hasPhotos)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        SectionHeader(section: section, fallback: "\(result.items.count) รายการ")
                    }
                }
            }
            .sheet(item: $selected) { item in
                DishDetailView(item: item, pageImage: result.pageImage, bahtPerYen: bahtPerYen)
            }
        }
    }
}

extension DishListView {
    private var hasPhotos: Bool {
        result.items.contains { $0.photo != nil }
    }

    /// Dishes grouped under the headings printed on the menu, in menu order.
    private var sections: [MenuSection<DishItem>] {
        MenuSection.group(result.items) { $0.dish }
    }
}

/// Menu heading in Thai with the printed Japanese next to it.
private struct SectionHeader: View {
    let section: MenuSection<DishItem>
    let fallback: String

    var body: some View {
        if section.titleTH.isEmpty && section.titleJA.isEmpty {
            Text(fallback)
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(section.titleTH.isEmpty ? section.titleJA : section.titleTH)
                    .font(.headline)
                    .foregroundStyle(.primary)
                if !section.titleTH.isEmpty && !section.titleJA.isEmpty {
                    Text(section.titleJA)
                        .font(.subheadline)
                        .environment(\.locale, Locale(identifier: "ja"))
                }
            }
            .textCase(nil)
        }
    }
}

#Preview {
    NavigationStack {
        DishListView(result: .preview)
            .navigationTitle("เมนู")
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
