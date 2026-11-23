import SwiftData
import UIKit

/// Saves scanned menus to SwiftData and loads them back for offline viewing.
@MainActor
enum HistoryStore {
    private struct PageData: Sendable {
        let index: Int
        let notes: String
        let dishesJSON: Data
        let imageJPEG: Data
    }

    /// Saves the pages that have at least one dish. Returns nil when there is nothing
    /// worth keeping or encoding fails.
    @discardableResult
    static func save(pages: [PageState], in context: ModelContext) async -> SavedMenu? {
        let readable = pages.compactMap { page -> (Int, MenuResult)? in
            guard let result = page.result, !result.items.isEmpty else { return nil }
            return (page.id, result)
        }
        guard let first = readable.first else { return nil }
        let dishes = readable.flatMap { $0.1.items.map(\.dish) }
        let inputs = readable.map { ($0.0, $0.1.pageImage, $0.1.items.map(\.dish), $0.1.notes) }
        let firstImage = first.1.pageImage

        // JPEG encoding of several large pages is slow; keep it off the main thread.
        let encoded = await Task.detached(priority: .utility) { () -> ([PageData], Data?)? in
            var result: [PageData] = []
            for (index, image, dishes, notes) in inputs {
                guard let jpeg = image.jpegData(compressionQuality: 0.8),
                    let json = try? JSONEncoder().encode(dishes)
                else { return nil }
                result.append(PageData(index: index, notes: notes, dishesJSON: json, imageJPEG: jpeg))
            }
            let thumbnail = ImageCropper.normalized(firstImage, maxLongEdge: 360)
                .jpegData(compressionQuality: 0.7)
            return (result, thumbnail)
        }.value
        guard let (pageData, thumbnail) = encoded else { return nil }

        let menu = SavedMenu(title: defaultTitle(for: dishes), dishCount: dishes.count, thumbnail: thumbnail)
        context.insert(menu)
        for data in pageData {
            let page = SavedPage(
                index: data.index, notes: data.notes, dishesJSON: data.dishesJSON, imageJPEG: data.imageJPEG)
            page.menu = menu
            context.insert(page)
        }
        try? context.save()
        return menu
    }

    /// Rebuilds the on-screen pages of a saved menu, cropping dish photos again from
    /// the stored page photos.
    static func load(_ menu: SavedMenu) async -> [PageState] {
        let stored = menu.pages
            .sorted { $0.index < $1.index }
            .map { PageData(index: $0.index, notes: $0.notes, dishesJSON: $0.dishesJSON, imageJPEG: $0.imageJPEG) }

        let loaded = await Task.detached(priority: .userInitiated) { () -> [(UIImage, [DishItem], String)] in
            stored.compactMap { data -> (UIImage, [DishItem], String)? in
                guard let raw = UIImage(data: data.imageJPEG) else { return nil }
                let image = ImageCropper.normalized(raw, maxLongEdge: ImageCropper.workingLongEdge)
                let dishes = (try? JSONDecoder().decode([Dish].self, from: data.dishesJSON)) ?? []
                let items = dishes.map { dish in
                    DishItem(dish: dish, photo: dish.photoBBox.flatMap { ImageCropper.crop(image, to: $0) })
                }
                return (image, items, data.notes)
            }
        }.value

        return loaded.enumerated().map { offset, page in
            PageState(
                id: offset, image: page.0,
                result: MenuResult(pageImage: page.0, items: page.1, notes: page.2), status: .done)
        }
    }

    /// Up to three section names, or the first dish when the menu has no headings.
    static func defaultTitle(for dishes: [Dish]) -> String {
        var sections: [String] = []
        for dish in dishes where !dish.sectionTH.isEmpty && !sections.contains(dish.sectionTH) {
            sections.append(dish.sectionTH)
            if sections.count == 3 { break }
        }
        if !sections.isEmpty { return sections.joined(separator: " · ") }
        return dishes.first?.nameTH ?? "เมนู"
    }
}
