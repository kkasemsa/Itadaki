import SwiftUI

/// One dish as a card: photo, names, price, and the control for adding it to the order.
struct DishCard: View {
    let item: DishItem
    let bahtPerYen: Double
    /// False for menus with no dish photos at all, where placeholders would only waste space.
    var showsThumbnail = true
    let quantity: Int
    let onAdd: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            if showsThumbnail {
                DishThumbnail(photo: item.photo)
                    .frame(width: 92, height: 92)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(item.dish.nameTH)
                    .font(.headline)
                // Large enough to point at when ordering from staff.
                Text(item.dish.nameJA)
                    .font(.title2.weight(.semibold))
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
                HStack(alignment: .lastTextBaseline) {
                    PriceLabel(priceYen: item.dish.priceYen, bahtPerYen: bahtPerYen)
                    Spacer(minLength: 8)
                    QuantityControl(quantity: quantity, onAdd: onAdd, onRemove: onRemove)
                }
                .padding(.top, 4)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))
        .overlay {
            if quantity > 0 {
                RoundedRectangle(cornerRadius: 20).strokeBorder(.tint, lineWidth: 1.5)
            }
        }
    }
}

/// "+" when nothing is picked; "− n +" once the dish is in the order.
struct QuantityControl: View {
    let quantity: Int
    let onAdd: () -> Void
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            if quantity > 0 {
                Button(action: onRemove) {
                    Image(systemName: "minus.circle")
                }
                .accessibilityLabel("ลดจำนวน")
                Text("\(quantity)")
                    .font(.headline.monospacedDigit())
                    .frame(minWidth: 18)
            }
            Button(action: onAdd) {
                Image(systemName: quantity > 0 ? "plus.circle.fill" : "plus.circle")
            }
            .accessibilityLabel("เพิ่มในรายการที่จะสั่ง")
        }
        .font(.title2)
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
                Color(.tertiarySystemFill)
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
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(PriceFormatter.yen(priceYen))
                    .font(.title3.weight(.bold).monospacedDigit())
                if let baht = PriceFormatter.baht(yen: priceYen, bahtPerYen: bahtPerYen) {
                    Text(baht)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct TagChips: View {
    let tags: [DishTag]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(tags, id: \.self) { tag in
                Text(tag.labelTH)
                    .font(.caption2.weight(.medium))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(tag.color.opacity(0.15), in: Capsule())
                    .foregroundStyle(tag.color)
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
