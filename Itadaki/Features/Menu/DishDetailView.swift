import SwiftUI

/// Detail sheet: larger photo, description, and where the dish is on the page.
struct DishDetailView: View {
    let item: DishItem
    let pageImage: UIImage
    let bahtPerYen: Double
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let photo = item.photo {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: 320)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                    }

                    // Shown first and very large so the phone can be handed to staff.
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.dish.nameJA)
                            .font(.system(size: 44, weight: .bold))
                            .minimumScaleFactor(0.5)
                            .environment(\.locale, Locale(identifier: "ja"))
                        if !item.dish.reading.isEmpty {
                            Text(item.dish.reading)
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
                    .textSelection(.enabled)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.dish.nameTH)
                            .font(.title2.bold())
                        PriceLabel(priceYen: item.dish.priceYen, bahtPerYen: bahtPerYen)
                        if !item.dish.tags.isEmpty {
                            TagChips(tags: item.dish.tags)
                        }
                    }
                    .textSelection(.enabled)

                    if !item.dish.descriptionTH.isEmpty {
                        Text(item.dish.descriptionTH)
                            .font(.body)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("ตำแหน่งในเมนู")
                            .font(.headline)
                        PageHighlightView(image: pageImage, highlight: item.dish.textBBox)
                    }
                }
                .padding(20)
            }
            .navigationTitle("รายละเอียด")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("ปิด") { dismiss() }
                }
            }
        }
    }
}

/// The original menu page with one box highlighted.
struct PageHighlightView: View {
    let image: UIImage
    let highlight: NormalizedRect?

    var body: some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .overlay {
                GeometryReader { proxy in
                    if let highlight {
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.accentColor, lineWidth: 3)
                            .background(Color.accentColor.opacity(0.15))
                            .frame(
                                width: highlight.width * proxy.size.width,
                                height: highlight.height * proxy.size.height
                            )
                            .offset(
                                x: highlight.x * proxy.size.width,
                                y: highlight.y * proxy.size.height)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

#Preview {
    DishDetailView(item: MenuResult.preview.items[0], pageImage: MenuResult.preview.pageImage, bahtPerYen: 0.23)
}
