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

    func testQuantityIsCapped() {
        let beer = Dish(nameJA: "ビール", nameTH: "เบียร์")
        var order = Order()
        for _ in 0..<50 { order.add(beer) }
        XCTAssertEqual(order.quantity(of: beer), Order.maximumQuantity)
    }
}
