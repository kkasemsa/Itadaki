import SwiftUI

struct DishRow: View {
    let item: DishItem
    let bahtPerYen: Double

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            DishThumbnail(photo: item.photo)
                .frame(width: 84, height: 84)
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 4) {
                Text(item.dish.nameTH)
                    .font(.title3.weight(.semibold))
                // Large enough to point at when ordering from staff.
                Text(item.dish.nameJA)
                    .font(.title2.weight(.medium))
                    .environment(\.locale, Locale(identifier: "ja"))
                if !item.dish.reading.isEmpty {
                    Text(item.dish.reading)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                PriceLabel(priceYen: item.dish.priceYen, bahtPerYen: bahtPerYen)
                if !item.dish.tags.isEmpty {
                    TagChips(tags: item.dish.tags)
                }
            }
        }
        .padding(.vertical, 4)
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
                Color(.secondarySystemBackground)
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
            HStack(spacing: 6) {
                Text(PriceFormatter.yen(priceYen))
                    .font(.subheadline.weight(.medium))
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
