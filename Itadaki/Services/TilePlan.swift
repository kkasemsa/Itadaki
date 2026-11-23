import Foundation

/// Splitting a page into overlapping strips so small text survives the downscale to
/// the upload size, and merging the per-strip results back into one page.
enum TilePlan {
    /// Fraction of a strip's length shared with its neighbour, so an item cut by one
    /// strip's edge is whole in the other.
    static let overlap = 0.12
    /// Below this long edge the upload is not downscaled, so strips add nothing.
    static let minimumLongEdgeToSplit = 1800.0

    /// Regions of the page to analyze, in reading order (left→right or top→bottom).
    /// Strips are cut across the long edge. Returns the whole page when splitting
    /// would not add detail.
    static func tiles(imageSize: CGSize, strips: Int) -> [NormalizedRect] {
        let full = NormalizedRect(x: 0, y: 0, width: 1, height: 1)
        let width = Double(imageSize.width)
        let height = Double(imageSize.height)
        guard strips > 1, max(width, height) >= minimumLongEdgeToSplit else { return [full] }

        let count = Double(strips)
        let length = (1 + overlap * (count - 1)) / count
        let step = (1 - length) / (count - 1)
        return (0..<strips).map { index in
            let start = Double(index) * step
            return width >= height
                ? NormalizedRect(x: start, y: 0, width: length, height: 1)
                : NormalizedRect(x: 0, y: start, width: 1, height: length)
        }
    }

    /// Converts a box relative to `tile` into page coordinates.
    static func toPage(_ rect: NormalizedRect, in tile: NormalizedRect) -> NormalizedRect {
        NormalizedRect(
            x: tile.x + rect.x * tile.width,
            y: tile.y + rect.y * tile.height,
            width: rect.width * tile.width,
            height: rect.height * tile.height)
    }

    /// Combines strip results (given in tile order) into one page: boxes are mapped to
    /// page coordinates and items seen twice in an overlap are kept once.
    static func merge(_ parts: [(tile: NormalizedRect, analysis: PageAnalysis)]) -> PageAnalysis {
        var dishes: [Dish] = []
        var notes: [String] = []
        for part in parts {
            for var dish in part.analysis.dishes {
                dish.textBBox = dish.textBBox.map { toPage($0, in: part.tile) }
                dish.photoBBox = dish.photoBBox.map { toPage($0, in: part.tile) }
                if let index = dishes.firstIndex(where: { isSameItem($0, dish) }) {
                    // Keep the more complete reading of an item cut by a strip edge.
                    if key(dish.nameJA).count > key(dishes[index].nameJA).count {
                        dishes[index] = dish
                    }
                } else {
                    dishes.append(dish)
                }
            }
            let note = part.analysis.notesTH
            if !note.isEmpty, !notes.contains(note) { notes.append(note) }
        }
        return PageAnalysis(dishes: dishes, notesTH: notes.joined(separator: "\n"))
    }

    static func isSameItem(_ a: Dish, _ b: Dish) -> Bool {
        guard let boxA = a.textBBox, let boxB = b.textBBox else { return false }
        let overlap = boxA.intersectionOverUnion(boxB)
        if overlap > 0.4 { return true }
        return key(a.nameJA) == key(b.nameJA) && overlap > 0.05
    }

    private static func key(_ name: String) -> String {
        String(name.unicodeScalars.filter { !CharacterSet.whitespacesAndNewlines.contains($0) })
    }
}

extension NormalizedRect {
    var area: Double { width * height }

    func intersectionOverUnion(_ other: NormalizedRect) -> Double {
        let w = min(x + width, other.x + other.width) - max(x, other.x)
        let h = min(y + height, other.y + other.height) - max(y, other.y)
        guard w > 0, h > 0 else { return 0 }
        let intersection = w * h
        return intersection / (area + other.area - intersection)
    }
}
