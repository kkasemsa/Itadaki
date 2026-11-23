import SwiftUI

/// The picked dishes in large Japanese, made to be shown to restaurant staff.
struct OrderSummaryView: View {
    let summary: OrderSummary
    let bahtPerYen: Double
    @Binding var order: Order
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("注文をお願いします")
                            .font(.system(size: 30, weight: .bold))
                            .environment(\.locale, Locale(identifier: "ja"))
                        Text("ขอสั่งอาหารตามนี้ครับ/ค่ะ — ยื่นหน้าจอนี้ให้พนักงานดู")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 0) {
                        ForEach(summary.lines) { line in
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(line.dish.nameJA)
                                        .font(.system(size: 32, weight: .bold))
                                        .minimumScaleFactor(0.6)
                                        .environment(\.locale, Locale(identifier: "ja"))
                                    Text(line.dish.nameTH)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 8)
                                Text("× \(line.quantity)")
                                    .font(.system(size: 32, weight: .bold).monospacedDigit())
                                    .foregroundStyle(.tint)
                            }
                            .padding(.vertical, 14)
                            if line.id != summary.lines.last?.id { Divider() }
                        }
                    }
                    .padding(.horizontal, 18)
                    .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 20))

                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline) {
                            Text("รวมโดยประมาณ")
                                .font(.headline)
                            Spacer()
                            Text(PriceFormatter.yen(summary.totalYen))
                                .font(.title2.bold().monospacedDigit())
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
            .background(Color(.systemGroupedBackground))
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
    OrderSummaryView(
        summary: order.summary(for: MenuResult.preview.items.map(\.dish)), bahtPerYen: 0.225, order: $order)
}
