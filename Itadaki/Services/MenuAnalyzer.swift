import Foundation

/// Turns menu page images into dishes. Implementations must be swappable
/// (Claude online, on-device offline, mock for previews/tests).
protocol MenuAnalyzer: Sendable {
    /// - Returns: one result per request, in the same order as `requests`.
    func analyze(_ requests: [PageRequest]) async throws -> [PageAnalysis]
}

/// One image to read: a whole menu page, or one zoomed strip of a page.
struct PageRequest: Sendable {
    /// JPEG to extract dishes from, already resized for upload. Boxes in the result
    /// are relative to this image.
    var image: Data
    /// JPEG of the whole page when `image` is only a strip of it, so headings and
    /// layout outside the strip are still visible.
    var overview: Data?

    init(image: Data, overview: Data? = nil) {
        self.image = image
        self.overview = overview
    }
}

/// How hard the analyzer should work. `thorough` is slower and is used as a second
/// attempt when a quick read finds nothing.
enum AnalysisEffort: Sendable {
    case quick, thorough
}

enum MenuAnalyzerError: Error, Equatable, LocalizedError {
    case missingAPIKey
    case unauthorized
    case rateLimited
    case overloaded
    case http(status: Int, message: String)
    case refused
    case truncated
    case invalidResponse(String)
    case network(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "ยังไม่ได้ใส่ API key กรุณาใส่ในหน้าตั้งค่า"
        case .unauthorized:
            return "API key ไม่ถูกต้องหรือถูกยกเลิกแล้ว กรุณาตรวจสอบในหน้าตั้งค่า"
        case .rateLimited:
            return "เรียกใช้งานถี่เกินไป รอสักครู่แล้วลองใหม่"
        case .overloaded:
            return "เซิร์ฟเวอร์ไม่ว่างชั่วคราว รอสักครู่แล้วลองใหม่"
        case .http(let status, let message):
            return "เซิร์ฟเวอร์ตอบกลับผิดพลาด (\(status)): \(message)"
        case .refused:
            return "โมเดลปฏิเสธที่จะอ่านรูปนี้ ลองถ่ายใหม่ให้เห็นเฉพาะเมนู"
        case .truncated:
            return "เมนูหน้านี้ยาวเกินไป ลองถ่ายทีละส่วนของเมนู"
        case .invalidResponse(let detail):
            return "อ่านผลลัพธ์ไม่ได้: \(detail)"
        case .network(let detail):
            return "เชื่อมต่อไม่ได้: \(detail)"
        }
    }
}
