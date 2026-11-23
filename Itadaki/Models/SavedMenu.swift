import Foundation
import SwiftData

/// A scanned menu kept in history. (Named `SavedMenu`, not `Menu`, because SwiftUI
/// already has a `Menu` view.)
@Model
final class SavedMenu {
    var createdAt: Date
    var title: String
    var dishCount: Int
    /// Small JPEG of the first page, for the history list.
    @Attribute(.externalStorage) var thumbnail: Data?
    @Relationship(deleteRule: .cascade, inverse: \SavedPage.menu) var pages: [SavedPage] = []

    init(createdAt: Date = .now, title: String, dishCount: Int, thumbnail: Data?) {
        self.createdAt = createdAt
        self.title = title
        self.dishCount = dishCount
        self.thumbnail = thumbnail
    }
}

/// One page of a saved menu: the photo and the dishes read from it.
@Model
final class SavedPage {
    var index: Int
    var notes: String
    /// `[Dish]` as JSON, in page coordinates.
    var dishesJSON: Data
    /// The page photo, upright, at working size.
    @Attribute(.externalStorage) var imageJPEG: Data
    var menu: SavedMenu?

    init(index: Int, notes: String, dishesJSON: Data, imageJPEG: Data) {
        self.index = index
        self.notes = notes
        self.dishesJSON = dishesJSON
        self.imageJPEG = imageJPEG
    }
}
