import SwiftUI

/// Detail sheet: larger photo, description, and where the dish is on the page.
struct DishDetailView: View {
    let item: DishItem
    let pageImage: UIImage
    let bahtPerYen: Double
    @Environment(\.dismiss) private var dismiss
    @State private var zoom: ZoomTarget?

    /// What the full-screen viewer is showing.
    private enum ZoomTarget: String, Identifiable {
        case photo, page
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if let photo = item.photo {
                        Image(uiImage: photo)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: 320)
                            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                            .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
                            .overlay(alignment: .bottomTrailing) { ZoomHint() }
                            .onTapGesture { zoom = .photo }
                            .accessibilityAddTraits(.isButton)
                            .accessibilityLabel("ขยายรูปอาหาร")
                    }

                    // Shown first and very large so the phone can be handed to staff.
                    VStack(alignment: .leading, spacing: 8) {
                        Text("これをください")
                            .font(Theme.mincho(15, relativeTo: .footnote))
                            .foregroundStyle(Theme.accent)
                            .environment(\.locale, Locale(identifier: "ja"))
                        Text(item.dish.nameJA)
                            .font(Theme.mincho(46, relativeTo: .largeTitle))
                            .foregroundStyle(Theme.ink)
                            .minimumScaleFactor(0.5)
                            .environment(\.locale, Locale(identifier: "ja"))
                        if !item.dish.reading.isEmpty {
                            Text(item.dish.reading)
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                    .paperCard()
                    .textSelection(.enabled)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(item.dish.nameTH)
                            .font(.title2.bold())
                            .foregroundStyle(Theme.ink)
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
                            .overlay(alignment: .bottomTrailing) { ZoomHint() }
                            .onTapGesture { zoom = .page }
                            .accessibilityAddTraits(.isButton)
                            .accessibilityLabel("ขยายรูปเมนู")
                        Text("แตะรูปเพื่อขยาย")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(20)
            }
            .paperBackground()
            .fullScreenCover(item: $zoom) { target in
                switch target {
                case .photo:
                    ImageZoomScreen(image: item.photo ?? pageImage)
                case .page:
                    ImageZoomScreen(image: pageImage, highlight: item.dish.textBBox)
                }
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

/// Small badge in an image's corner showing it can be opened full screen.
struct ZoomHint: View {
    var body: some View {
        Image(systemName: "arrow.up.left.and.arrow.down.right")
            .font(.footnote.weight(.bold))
            .foregroundStyle(.white)
            .frame(width: 32, height: 32)
            .background(.black.opacity(0.5), in: Circle())
            .padding(10)
            .accessibilityHidden(true)
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
                            .stroke(Theme.accent, lineWidth: 3)
                            .background(Theme.accent.opacity(0.18))
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
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

#Preview {
    DishDetailView(item: MenuResult.preview.items[0], pageImage: MenuResult.preview.pageImage, bahtPerYen: 0.23)
}
