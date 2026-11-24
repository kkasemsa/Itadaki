import XCTest
@testable import Itadaki

final class OrderTests: XCTestCase {
    func testQuantitiesAndSummary() {
        let ramen = Dish(nameJA: "ラーメン", nameTH: "ราเมง", priceYen: 850)
        let beer = Dish(nameJA: "ビール", nameTH: "เบียร์", priceYen: 550)
        let special = Dish(nameJA: "おすすめ", nameTH: "เมนูแนะนำ")
        var order = Order()
        XCTAssertTrue(order.isEmpty)

        order.add(beer); order.add(beer); order.add(ramen); order.add(special)
        XCTAssertEqual(order.quantity(of: beer), 2)
        XCTAssertEqual(order.itemCount, 4)

        let summary = order.summary(for: [ramen, beer, special])
        XCTAssertEqual(summary.lines.map(\.dish.nameJA), ["ラーメン", "ビール", "おすすめ"], "menu order")
        XCTAssertEqual(summary.lines.map(\.quantity), [1, 2, 1])
        XCTAssertEqual(summary.totalYen, 850 + 1100)
        XCTAssertEqual(summary.unpricedLineCount, 1)

        order.remove(ramen); order.remove(ramen)
        XCTAssertEqual(order.quantity(of: ramen), 0)
        XCTAssertEqual(order.summary(for: [ramen, beer, special]).lines.count, 2)
        order.clear()
        XCTAssertTrue(order.isEmpty)
    }

    func testChoicesAreOrderedSeparately() {
        let tofu = Dish(
            nameJA: "ご豆腐", nameTH: "เต้าหู้เย็น", priceYen: 400,
            options: [DishOption(nameJA: "ゴマ", nameTH: "รสงา"), DishOption(nameJA: "土佐", nameTH: "โทสะ")])
        let tomato = Dish(nameJA: "トマト", nameTH: "มะเขือเทศ", priceYen: 300)
        var order = Order()
        order.add(tofu, option: 1); order.add(tofu, option: 1); order.add(tofu, option: 0); order.add(tomato)

        XCTAssertEqual(order.quantity(of: tofu, option: 1), 2)
        XCTAssertEqual(order.quantity(of: tofu), 0, "the dish itself was not picked, only its choices")
        XCTAssertEqual(order.totalQuantity(of: tofu), 3)

        let summary = order.summary(for: [tofu, tomato])
        XCTAssertEqual(summary.lines.map { $0.option?.nameJA ?? $0.dish.nameJA }, ["ゴマ", "土佐", "トマト"])
        XCTAssertEqual(summary.lines.map(\.quantity), [1, 2, 1])
        XCTAssertEqual(summary.totalYen, 400 * 3 + 300)
        XCTAssertEqual(summary.itemCount, 4)
        XCTAssertEqual(Set(summary.lines.map(\.id)).count, 3, "line ids are unique")

        order.remove(tofu, option: 0)
        XCTAssertEqual(order.summary(for: [tofu, tomato]).lines.count, 2, "one line removed, the rest kept")
    }

    func testRomaji() {
        XCTAssertEqual(Romaji.convert("からあげていしょく"), "karaageteishoku")
        XCTAssertEqual(Romaji.convert("ごとうふ"), "gotoufu")
        XCTAssertEqual(Romaji.convert("さっぽろ"), "sapporo")
        XCTAssertEqual(Romaji.convert("まっちゃ"), "matcha")
        XCTAssertEqual(Romaji.convert("しゃぶしゃぶ"), "shabushabu")
        XCTAssertEqual(Romaji.convert("ぎゅうどん"), "gyuudon")
        XCTAssertEqual(Romaji.convert("びーる"), "biiru")
        XCTAssertEqual(Romaji.convert("ラーメン"), "raamen", "katakana is converted too")
        XCTAssertEqual(Romaji.convert("ふぁみりー"), "famirii")
        XCTAssertEqual(Romaji.convert("さけ・うめ（しお）"), "sake・ume（shio）", "other characters pass through")
        XCTAssertEqual(Romaji.convert(""), "")
    }

    func testQuantityIsCapped() {
        let beer = Dish(nameJA: "ビール", nameTH: "เบียร์")
        var order = Order()
        for _ in 0..<50 { order.add(beer) }
        XCTAssertEqual(order.quantity(of: beer), Order.maximumQuantity)
    }
}
