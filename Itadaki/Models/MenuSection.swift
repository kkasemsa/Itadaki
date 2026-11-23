import Foundation

/// A run of consecutive items printed under the same menu heading.
struct MenuSection<Item> {
    var titleTH: String
    var titleJA: String
    var items: [Item]

    /// Splits `items` into runs that share a heading, keeping menu order. Items are
    /// grouped only when adjacent, so a heading that reappears later starts a new section.
    static func group(_ items: [Item], dish: (Item) -> Dish) -> [MenuSection<Item>] {
        var sections: [MenuSection<Item>] = []
        for item in items {
            let d = dish(item)
            if let last = sections.indices.last,
                sections[last].titleJA == d.sectionJA, sections[last].titleTH == d.sectionTH
            {
                sections[last].items.append(item)
            } else {
                sections.append(MenuSection(titleTH: d.sectionTH, titleJA: d.sectionJA, items: [item]))
            }
        }
        return sections
    }
}
