import XCTest
@testable import Itadaki

final class PriceFormatterTests: XCTestCase {
    func testYen() {
        XCTAssertEqual(PriceFormatter.yen(0), "¥0")
        XCTAssertEqual(PriceFormatter.yen(980), "¥980")
        XCTAssertEqual(PriceFormatter.yen(1280), "¥1,280")
        XCTAssertEqual(PriceFormatter.yen(1234567), "¥1,234,567")
    }

    func testBaht() {
        XCTAssertEqual(PriceFormatter.baht(yen: 980, bahtPerYen: 0.23), "≈ ฿225")
        XCTAssertEqual(PriceFormatter.baht(yen: 10000, bahtPerYen: 0.23), "≈ ฿2,300")
        XCTAssertNil(PriceFormatter.baht(yen: 980, bahtPerYen: 0))
        XCTAssertNil(PriceFormatter.baht(yen: 980, bahtPerYen: -1))
        XCTAssertNil(PriceFormatter.baht(yen: 980, bahtPerYen: .nan))
    }
}
