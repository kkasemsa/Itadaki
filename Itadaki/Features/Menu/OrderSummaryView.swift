import SwiftUI

/// The picked dishes in large Japanese, made to be shown to restaurant staff. Each
/// line can be adjusted or removed here.
struct OrderSummaryView: View {
    /// Every dish of the scan, in menu order.
    let dishes: [Dish]
    let bahtPerYen: Double
    @Binding var order: Order
    @Environment(\.dismiss) private var dismiss

    private var summary: OrderSummary { order.summary(for: dishes) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("注文をお願いします")
                            .font(Theme.mincho(32, relativeTo: .largeTitle))
                            .foregroundStyle(Theme.ink)
                            .environment(\.locale, Locale(identifier: "ja"))
                        Text("ขอสั่งอาหารตามนี้ครับ/ค่ะ — ยื่นหน้าจอนี้ให้พนักงานดู")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 0) {
                        ForEach(summary.lines) { line in
                            lineRow(line)
                            if line.id != summary.lines.last?.id {
                                Line()
                                    .stroke(Color.primary.opacity(0.18), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                                    .frame(height: 1)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 4)
                    .paperCard()

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("รวมโดยประมาณ")
                                .font(.headline)
                            Spacer()
                            Text(PriceFormatter.yen(summary.totalYen))
                                .font(.system(.title, design: .serif).weight(.bold).monospacedDigit())
                                .foregroundStyle(Theme.ink)
                        }
                        if let baht = PriceFormatter.baht(yen: summary.totalYen, bahtPerYen: bahtPerYen) {
                            Text(baht)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        Text(totalCaveat)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                    .padding(.horizontal, 4)
                }
                .padding(20)
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
            }
            .paperBackground()
            .navigationTitle("รายการที่จะสั่ง")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("ล้างรายการ", role: .destructive) {
                        order.clear()
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("ปิด") { dismiss() }
                }
            }
            .onChange(of: order.isEmpty) { _, isEmpty in
                if isEmpty { dismiss() }
            }
        }
    }

    private func lineRow(_ line: OrderSummary.Line) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(line.dish.nameJA)
                        .font(Theme.mincho(32, relativeTo: .largeTitle))
                        .foregroundStyle(Theme.ink)
                        .minimumScaleFactor(0.6)
                        .environment(\.locale, Locale(identifier: "ja"))
                    if let option = line.option {
                        Text(option.nameJA)
                            .font(Theme.mincho(28, relativeTo: .title))
                            .foregroundStyle(Theme.accent)
                            .environment(\.locale, Locale(identifier: "ja"))
                    }
                }
                Spacer(minLength: 8)
                Text("\(line.quantity)")
                    .font(.system(size: 26, weight: .bold, design: .serif).monospacedDigit())
                    .foregroundStyle(.white)
                    .frame(width: 50, height: 50)
                    .background(Theme.accent, in: Circle())
            }

            // For the user, not the staff: what the line is, and controls to change it.
            HStack(alignment: .center, spacing: 8) {
                Text(thaiLabel(line))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 8)
                QuantityControl(
                    quantity: line.quantity,
                    onAdd: { order.add(line.dish, option: line.optionIndex) },
                    onRemove: { order.remove(line.dish, option: line.optionIndex) },
                    showsCount: false)
            }
        }
        .padding(.vertical, 16)
    }

    private func thaiLabel(_ line: OrderSummary.Line) -> String {
        guard let option = line.option, !option.nameTH.isEmpty else { return line.dish.nameTH }
        return "\(line.dish.nameTH) · \(option.nameTH)"
    }

    /// A horizontal rule, drawn as a shape so it can be dashed like an order slip.
    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return path
        }
    }

    private var totalCaveat: String {
        var text = "ยอดจริงอาจต่างจากนี้ เช่น ภาษี ค่าที่นั่ง หรือราคาตามขนาด"
        if summary.unpricedLineCount > 0 {
            text = "ไม่รวม \(summary.unpricedLineCount) รายการที่เมนูไม่ได้ระบุราคา " + text
        }
        return text
    }
}

#Preview {
    @Previewable @State var order: Order = {
        var order = Order()
        for item in MenuResult.preview.items.prefix(3) { order.add(item.dish) }
        return order
    }()
    OrderSummaryView(dishes: MenuResult.preview.items.map(\.dish), bahtPerYen: 0.225, order: $order)
}
