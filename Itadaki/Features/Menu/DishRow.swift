import SwiftUI

/// One dish as a card: photo, names, price, and the control for adding it to the order.
struct DishCard: View {
    let item: DishItem
    let bahtPerYen: Double
    /// False for menus with no dish photos at all, where placeholders would only waste space.
    var showsThumbnail = true
    let quantity: Int
    /// True for the dish currently picked out in the split view.
    var isHighlighted = false
    /// When set, the card shows a button that opens the dish's details. Used in the
    /// split view, where tapping the card selects it instead.
    var onInfo: (() -> Void)?
    let onAdd: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            if showsThumbnail {
                DishThumbnail(photo: item.photo)
                    .frame(width: 96, height: 96)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(item.dish.nameTH)
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                // Large enough to point at when ordering from staff.
                Text(item.dish.nameJA)
                    .font(Theme.mincho(24))
                    .foregroundStyle(Theme.ink)
                    .environment(\.locale, Locale(identifier: "ja"))
                if !item.dish.reading.isEmpty {
                    Text(item.dish.reading)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if !item.dish.tags.isEmpty {
                    TagChips(tags: item.dish.tags)
                        .padding(.top, 2)
                }
                HStack(alignment: .center) {
                    PriceLabel(priceYen: item.dish.priceYen, bahtPerYen: bahtPerYen)
                    Spacer(minLength: 8)
                    if let onInfo {
                        Button(action: onInfo) {
                            Image(systemName: "info")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(Theme.ink)
                                .frame(width: 34, height: 34)
                                .background(Color.primary.opacity(0.07), in: Circle())
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel("ดูรายละเอียด")
                    }
                    QuantityControl(quantity: quantity, onAdd: onAdd, onRemove: onRemove)
                }
                .padding(.top, 4)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .paperCard()
        .overlay {
            if quantity > 0 || isHighlighted {
                RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                    .strokeBorder(Theme.accent, lineWidth: isHighlighted ? 3 : 2)
            }
        }
    }
}

/// A round "+" when nothing is picked; "− n +" once the dish is in the order.
struct QuantityControl: View {
    let quantity: Int
    let onAdd: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            if quantity > 0 {
                Button(action: onRemove) {
                    Image(systemName: "minus")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.accent)
                        .frame(width: 34, height: 34)
                        .background(Theme.accent.opacity(0.12), in: Circle())
                }
                .accessibilityLabel("ลดจำนวน")
                Text("\(quantity)")
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(Theme.ink)
                    .frame(minWidth: 16)
            }
            Button(action: onAdd) {
                Image(systemName: "plus")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(quantity > 0 ? .white : Theme.accent)
                    .frame(width: 34, height: 34)
                    .background(quantity > 0 ? Theme.accent : Theme.accent.opacity(0.12), in: Circle())
            }
            .accessibilityLabel("เพิ่มในรายการที่จะสั่ง")
        }
        .buttonStyle(.borderless)
        .sensoryFeedback(.selection, trigger: quantity)
    }
}

/// Cropped dish photo, or a neutral placeholder when the menu shows none.
struct DishThumbnail: View {
    let photo: UIImage?

    var body: some View {
        if let photo {
            Color.clear.overlay {
                Image(uiImage: photo).resizable().scaledToFill()
            }
            .clipped()
        } else {
            ZStack {
                Theme.paper
                Image(systemName: "fork.knife")
                    .font(.title2)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

struct PriceLabel: View {
    let priceYen: Int?
    let bahtPerYen: Double

    var body: some View {
        if let priceYen {
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text(PriceFormatter.yen(priceYen))
                    .font(.system(.title3, design: .serif).weight(.bold).monospacedDigit())
                    .foregroundStyle(Theme.ink)
                if let baht = PriceFormatter.baht(yen: priceYen, bahtPerYen: bahtPerYen) {
                    Text(baht)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        } else {
            Text("ไม่ระบุราคา")
                .font(.footnote)
                .foregroundStyle(.tertiary)
        }
    }
}

struct TagChips: View {
    let tags: [DishTag]

    var body: some View {
        HStack(spacing: 5) {
            ForEach(tags, id: \.self) { tag in
                HStack(spacing: 4) {
                    Circle().fill(tag.color).frame(width: 6, height: 6)
                    Text(tag.labelTH)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.05), in: Capsule())
            }
        }
    }
}

extension DishTag {
    var color: Color {
        switch self {
        case .pork: return .pink
        case .beef: return .brown
        case .chicken: return .orange
        case .seafood: return .blue
        case .raw: return .teal
        case .spicy: return .red
        case .alcohol: return .purple
        case .vegetarian: return .green
        }
    }
}
