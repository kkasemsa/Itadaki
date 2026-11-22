import XCTest
@testable import Itadaki

final class CropMathTests: XCTestCase {
    private let size = CGSize(width: 1000, height: 2000)

    func testCropWithoutPadding() {
        let rect = CropMath.cropRect(
            for: NormalizedRect(x: 0.1, y: 0.25, width: 0.5, height: 0.1), imageSize: size, padding: 0)
        XCTAssertEqual(rect, CGRect(x: 100, y: 500, width: 500, height: 200))
    }

    func testDefaultPaddingGrowsEachSide() {
        let rect = CropMath.cropRect(
            for: NormalizedRect(x: 0.1, y: 0.25, width: 0.5, height: 0.1), imageSize: size)
        // 4% of 500 px = 20 px, 4% of 200 px = 8 px
        XCTAssertEqual(rect, CGRect(x: 80, y: 492, width: 540, height: 216))
    }

    func testPaddingIsClampedToImage() {
        let rect = CropMath.cropRect(
            for: NormalizedRect(x: 0, y: 0.9, width: 1, height: 0.1), imageSize: size, padding: 0.5)
        XCTAssertEqual(rect, CGRect(x: 0, y: 1700, width: 1000, height: 300))
    }

    func testTinyCropIsRejected() {
        XCTAssertNil(CropMath.cropRect(
            for: NormalizedRect(x: 0.5, y: 0.5, width: 0.005, height: 0.2), imageSize: size))
        XCTAssertNil(CropMath.cropRect(
            for: NormalizedRect(x: 0, y: 0, width: 1, height: 1), imageSize: .zero))
    }
}
