import Foundation

enum PriceFormatter {
    /// "¥1,280"
    static func yen(_ amount: Int) -> String {
        "¥" + grouped(amount)
    }

    /// "≈ ฿294" for a yen amount at `bahtPerYen`. Nil when no usable rate is set.
    static func baht(yen amount: Int, bahtPerYen: Double) -> String? {
        guard bahtPerYen.isFinite, bahtPerYen > 0 else { return nil }
        let value = (Double(amount) * bahtPerYen).rounded()
        guard value.isFinite, abs(value) < 1e15 else { return nil }
        return "≈ ฿" + grouped(Int(value))
    }

    /// Thousands grouping done by hand so output does not depend on device locale.
    static func grouped(_ amount: Int) -> String {
        let digits = String(amount.magnitude)
        var out = ""
        for (offset, character) in digits.enumerated() {
            if offset > 0, (digits.count - offset) % 3 == 0 { out.append(",") }
            out.append(character)
        }
        return amount < 0 ? "-" + out : out
    }
}
