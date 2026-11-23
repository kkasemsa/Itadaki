import XCTest
@testable import Itadaki

final class DishDecodingTests: XCTestCase {
    private func decodePage(_ json: String) throws -> PageAnalysis {
        try JSONDecoder().decode(PageAnalysis.self, from: Data(json.utf8))
    }

    func testFixtureDecodes() throws {
        let page = try MockMenuAnalyzer.fixturePage()
        XCTAssertEqual(page.dishes.count, 5)
        let first = page.dishes[0]
        XCTAssertEqual(first.nameJA, "唐揚げ定食")
        XCTAssertEqual(first.reading, "からあげていしょく")
        XCTAssertEqual(first.nameTH, "ชุดไก่ทอดคาราอาเกะ")
        XCTAssertEqual(first.priceYen, 980)
        XCTAssertEqual(first.tags, [.chicken])
        let photo = try XCTUnwrap(first.photoBBox)
        XCTAssertEqual(photo.x, 0.55, accuracy: 1e-9)
        XCTAssertEqual(photo.y, 0.08, accuracy: 1e-9)
        XCTAssertEqual(photo.width, 0.35, accuracy: 1e-9)
        XCTAssertEqual(photo.height, 0.22, accuracy: 1e-9)
        XCTAssertNil(page.dishes[2].photoBBox)
        XCTAssertNil(page.dishes[4].priceYen)
        XCTAssertFalse(page.notesTH.isEmpty)
    }

    func testSectionsGroupConsecutiveDishes() throws {
        func dish(_ name: String, _ ja: String, _ th: String) -> Dish {
            Dish(nameJA: name, nameTH: name, sectionJA: ja, sectionTH: th)
        }
        let dishes = [
            dish("a", "刺身", "ซาชิมิ"), dish("b", "刺身", "ซาชิมิ"),
            dish("c", "", ""),
            dish("d", "焼き物", "ของย่าง"),
            dish("e", "刺身", "ซาชิมิ"),
        ]
        let sections = MenuSection.group(dishes) { $0 }
        XCTAssertEqual(sections.map(\.titleJA), ["刺身", "", "焼き物", "刺身"])
        XCTAssertEqual(sections.map { $0.items.map(\.nameJA) }, [["a", "b"], ["c"], ["d"], ["e"]])
        XCTAssertEqual(sections[0].titleTH, "ซาชิมิ")
        XCTAssertTrue(MenuSection.group([Dish]()) { $0 }.isEmpty)

        let fixture = try MockMenuAnalyzer.fixturePage()
        XCTAssertEqual(fixture.dishes[0].sectionJA, "定食")
        XCTAssertEqual(fixture.dishes[4].sectionTH, "")
    }

    func testDishRoundTripsThroughJSON() throws {
        let original = Dish(
            nameJA: "唐揚げ定食", reading: "からあげていしょく", nameTH: "ชุดไก่ทอด",
            descriptionTH: "ไก่ทอด", priceYen: 980, tags: [.chicken, .spicy],
            textBBox: NormalizedRect(x: 0.125, y: 0.25, width: 0.5, height: 0.0625),
            photoBBox: nil, sectionJA: "定食", sectionTH: "ชุดอาหาร")
        let unpriced = Dish(nameJA: "おすすめ", nameTH: "เมนูแนะนำ")

        let data = try JSONEncoder().encode([original, unpriced])
        let decoded = try JSONDecoder().decode([Dish].self, from: data)

        XCTAssertEqual(decoded, [original, unpriced], "ids, boxes and optional fields survive")
    }

    func testLenientFields() throws {
        let page = try decodePage("""
        {"dishes":[{"name_ja":"ラーメン","name_th":"ราเมง","price_yen":850.0,
          "tags":["Pork","unknown","pork"],"text_bbox":[0.1,0.1,0.2],"photo_bbox":[0.9,0.9,0.5,0.5]}]}
        """)
        let dish = page.dishes[0]
        XCTAssertEqual(dish.priceYen, 850)
        XCTAssertEqual(dish.tags, [.pork])
        XCTAssertEqual(dish.reading, "")
        XCTAssertNil(dish.textBBox, "wrong element count is dropped")
        let photo = try XCTUnwrap(dish.photoBBox)
        XCTAssertEqual(photo.x, 0.9, accuracy: 1e-9)
        XCTAssertEqual(photo.width, 0.1, accuracy: 1e-9, "clamped to the image")
        XCTAssertEqual(page.notesTH, "")
    }

    func testMissingThaiNameFails() {
        XCTAssertThrowsError(try decodePage(#"{"dishes":[{"name_ja":"ラーメン"}]}"#))
        XCTAssertThrowsError(try decodePage(#"{"dishes":[{"name_ja":"ラーメン","name_th":"  "}]}"#))
        XCTAssertThrowsError(try decodePage(#"{"notes_th":"x"}"#))
    }

    func testNormalizedRectRejectsDegenerateBoxes() {
        XCTAssertNil(NormalizedRect(array: [0.5, 0.5, 0, 0.2]))
        XCTAssertNil(NormalizedRect(array: [1.2, 0.5, 0.2, 0.2]))
        XCTAssertNil(NormalizedRect(array: [0.1, 0.1, .nan, 0.2]))
        XCTAssertEqual(
            NormalizedRect(array: [-0.1, 0, 0.5, 2]), NormalizedRect(x: 0, y: 0, width: 0.4, height: 1))
    }
}
