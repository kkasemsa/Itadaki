import Foundation

/// Dishes the user has picked to order from the current menu, with quantities. A dish
/// with choices (fillings, flavours…) is ordered per choice.
struct Order: Equatable {
    static let maximumQuantity = 20

    /// One orderable thing: a dish, or one choice of a dish.
    struct Key: Hashable {
        let dishID: UUID
        /// Index into the dish's `options`, or nil for the dish itself.
        let option: Int?
    }

    private(set) var quantities: [Key: Int] = [:]

    func quantity(of dish: Dish, option: Int? = nil) -> Int {
        quantities[Key(dishID: dish.id, option: option)] ?? 0
    }

    /// Portions of this dish across all of its choices.
    func totalQuantity(of dish: Dish) -> Int {
        quantities.reduce(0) { $1.key.dishID == dish.id ? $0 + $1.value : $0 }
    }

    /// Total number of portions across all picked dishes.
    var itemCount: Int { quantities.values.reduce(0, +) }
    var isEmpty: Bool { quantities.isEmpty }

    mutating func add(_ dish: Dish, option: Int? = nil) {
        let key = Key(dishID: dish.id, option: option)
        quantities[key] = min((quantities[key] ?? 0) + 1, Self.maximumQuantity)
    }

    mutating func remove(_ dish: Dish, option: Int? = nil) {
        let key = Key(dishID: dish.id, option: option)
        let next = (quantities[key] ?? 0) - 1
        quantities[key] = next > 0 ? next : nil
    }

    mutating func clear() { quantities = [:] }

    /// Picked dishes in menu order (a dish's choices in the order printed) with the
    /// bill total.
    func summary(for dishes: [Dish]) -> OrderSummary {
        var lines: [OrderSummary.Line] = []
        var total = 0
        var unpriced = 0
        for dish in dishes {
            let options: [Int?] = [nil] + dish.options.indices.map { Optional($0) }
            for option in options {
                let count = quantity(of: dish, option: option)
                guard count > 0 else { continue }
                lines.append(OrderSummary.Line(dish: dish, optionIndex: option, quantity: count))
                if let price = dish.priceYen { total += price * count } else { unpriced += 1 }
            }
        }
        return OrderSummary(lines: lines, totalYen: total, unpricedLineCount: unpriced)
    }
}

struct OrderSummary: Equatable {
    struct Line: Equatable, Identifiable {
        let dish: Dish
        /// Which of the dish's choices this line is for, if any.
        let optionIndex: Int?
        let quantity: Int

        var id: String { "\(dish.id.uuidString)-\(optionIndex.map(String.init) ?? "dish")" }

        var option: DishOption? {
            optionIndex.flatMap { dish.options.indices.contains($0) ? dish.options[$0] : nil }
        }
    }
    let lines: [Line]
    /// Sum of priced lines only.
    let totalYen: Int
    /// Lines with no printed price, which the total cannot include.
    let unpricedLineCount: Int
    /// Portions across all lines.
    var itemCount: Int { lines.reduce(0) { $0 + $1.quantity } }
}
