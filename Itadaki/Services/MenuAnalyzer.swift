import Foundation

/// Turns menu page images into dishes. Implementations must be swappable
/// (Claude online, on-device offline, mock for previews/tests).
protocol MenuAnalyzer: Sendable {
    /// - Parameter images: one JPEG per menu page, already resized for upload.
    /// - Returns: one result per page, in the same order as `images`.
    func analyze(_ images: [Data]) async throws -> [PageAnalysis]
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
