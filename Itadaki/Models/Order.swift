import Foundation

/// Dishes the user has picked to order from the current menu, with quantities.
struct Order: Equatable {
    static let maximumQuantity = 20
    private(set) var quantities: [UUID: Int] = [:]

    func quantity(of dish: Dish) -> Int { quantities[dish.id] ?? 0 }

    /// Total number of portions across all picked dishes.
    var itemCount: Int { quantities.values.reduce(0, +) }
    var isEmpty: Bool { quantities.isEmpty }

    mutating func add(_ dish: Dish) {
        quantities[dish.id] = min(quantity(of: dish) + 1, Self.maximumQuantity)
    }

    mutating func remove(_ dish: Dish) {
        let next = quantity(of: dish) - 1
        quantities[dish.id] = next > 0 ? next : nil
    }

    mutating func clear() { quantities = [:] }

    /// Picked dishes in menu order with the bill total.
    func summary(for dishes: [Dish]) -> OrderSummary {
        var lines: [OrderSummary.Line] = []
        var total = 0
        var unpriced = 0
        for dish in dishes {
            let count = quantity(of: dish)
            guard count > 0 else { continue }
            lines.append(OrderSummary.Line(dish: dish, quantity: count))
            if let price = dish.priceYen { total += price * count } else { unpriced += 1 }
        }
        return OrderSummary(lines: lines, totalYen: total, unpricedLineCount: unpriced)
    }
}

struct OrderSummary: Equatable {
    struct Line: Equatable, Identifiable {
        let dish: Dish
        let quantity: Int
        var id: UUID { dish.id }
    }
    let lines: [Line]
    /// Sum of priced lines only.
    let totalYen: Int
    /// Lines with no printed price, which the total cannot include.
    let unpricedLineCount: Int
}
