import XCTest
@testable import Itadaki

final class TilePlanTests: XCTestCase {
    private func dish(_ name: String, _ box: [Double]?) -> Dish {
        Dish(nameJA: name, nameTH: name, textBBox: box.flatMap(NormalizedRect.init(array:)))
    }

    func testSmallOrSingleStripImagesAreNotSplit() {
        let full = [NormalizedRect(x: 0, y: 0, width: 1, height: 1)]
        XCTAssertEqual(TilePlan.tiles(imageSize: CGSize(width: 550, height: 347), strips: 3), full)
        XCTAssertEqual(TilePlan.tiles(imageSize: CGSize(width: 3000, height: 2250), strips: 1), full)
    }

    func testStripsCutAcrossLongEdgeAndCoverThePage() {
        let landscape = TilePlan.tiles(imageSize: CGSize(width: 3000, height: 2250), strips: 2)
        XCTAssertEqual(landscape.count, 2)
        XCTAssertEqual(landscape[0].x, 0)
        XCTAssertEqual(landscape[0].width, 0.56, accuracy: 1e-9)
        XCTAssertEqual(landscape[1].x + landscape[1].width, 1, accuracy: 1e-9)
        XCTAssertEqual(landscape[0].height, 1)

        let portrait = TilePlan.tiles(imageSize: CGSize(width: 2250, height: 3000), strips: 3)
        XCTAssertEqual(portrait.count, 3)
        XCTAssertEqual(portrait[0].width, 1)
        XCTAssertEqual(portrait[2].y + portrait[2].height, 1, accuracy: 1e-9)
        for (a, b) in zip(portrait, portrait.dropFirst()) {
            XCTAssertGreaterThan(a.y + a.height, b.y, "neighbouring strips overlap")
        }
    }

    func testToPage() {
        let tile = NormalizedRect(x: 0.44, y: 0, width: 0.56, height: 1)
        let mapped = TilePlan.toPage(NormalizedRect(x: 0.5, y: 0.2, width: 0.25, height: 0.1), in: tile)
        XCTAssertEqual(mapped.x, 0.72, accuracy: 1e-9)
        XCTAssertEqual(mapped.y, 0.2, accuracy: 1e-9)
        XCTAssertEqual(mapped.width, 0.14, accuracy: 1e-9)
        XCTAssertEqual(mapped.height, 0.1, accuracy: 1e-9)
    }

    func testMergeMapsBoxesAndDropsOverlapDuplicates() {
        let left = NormalizedRect(x: 0, y: 0, width: 0.56, height: 1)
        let right = NormalizedRect(x: 0.44, y: 0, width: 0.56, height: 1)
        // "刺身" sits in the overlap: page x 0.45…0.55 in both strips. The left strip
        // only read part of the name of "焼き鳥盛り合わせ" at its edge.
        let merged = TilePlan.merge([
            (left, PageAnalysis(dishes: [
                dish("ラーメン", [0.1, 0.1, 0.3, 0.05]),
                dish("刺身", [0.45 / 0.56, 0.3, 0.1 / 0.56, 0.05]),
                dish("焼き鳥", [0.46 / 0.56, 0.5, 0.1 / 0.56, 0.05]),
            ], notesTH: "ราคารวมภาษี")),
            (right, PageAnalysis(dishes: [
                dish("刺 身", [0.01 / 0.56, 0.3, 0.1 / 0.56, 0.05]),
                dish("焼き鳥盛り合わせ", [0.02 / 0.56, 0.5, 0.12 / 0.56, 0.05]),
                dish("ビール", [0.5, 0.8, 0.3, 0.05]),
            ], notesTH: "ราคารวมภาษี")),
        ])
        XCTAssertEqual(merged.dishes.map(\.nameJA), ["ラーメン", "刺身", "焼き鳥盛り合わせ", "ビール"])
        XCTAssertEqual(merged.notesTH, "ราคารวมภาษี")
        let beer = merged.dishes[3].textBBox!
        XCTAssertEqual(beer.x, 0.44 + 0.5 * 0.56, accuracy: 1e-9)
    }

    func testSameNameInDifferentPlacesIsKept() {
        let full = NormalizedRect(x: 0, y: 0, width: 1, height: 1)
        let merged = TilePlan.merge([
            (full, PageAnalysis(dishes: [
                dish("ビール", [0.1, 0.1, 0.3, 0.05]), dish("ビール", [0.1, 0.6, 0.3, 0.05]),
                dish("お茶", nil), dish("お茶", nil),
            ]))
        ])
        XCTAssertEqual(merged.dishes.count, 4)
    }
}
