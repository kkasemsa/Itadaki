import SwiftUI

/// Analyzes one photo and shows progress, an error with retry, or the dish list.
struct ScanView: View {
    @State private var model: ScanViewModel
    @State private var order = Order()
    @Environment(\.dismiss) private var dismiss
    private let image: UIImage

    init(image: UIImage) {
        self.image = image
        _model = State(initialValue: ScanViewModel(image: image))
    }

    var body: some View {
        Group {
            switch model.phase {
            case .tooSmall:
                tooSmall
            case .failed(let message):
                ContentUnavailableView {
                    Label("อ่านเมนูไม่สำเร็จ", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button("ลองใหม่") { Task { await model.retry() } }
                        .buttonStyle(.borderedProminent)
                }
            case .analyzing, .done:
                if let result = model.result, !result.items.isEmpty {
                    DishListView(result: result, order: $order, progress: progressText)
                } else if model.phase == .done {
                    UnreadableView(image: image, notes: model.result?.notes ?? "") { dismiss() }
                } else {
                    analyzing
                }
            }
        }
        .navigationTitle("เมนู")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.start() }
    }

    /// Status line shown under the list while more of the page is still being read.
    private var progressText: String? {
        if model.phase == .analyzing {
            return "กำลังอ่านส่วนที่เหลือ… (\(model.completedParts)/\(model.totalParts))"
        }
        if model.failedParts > 0 {
            return "อ่านไม่สำเร็จ \(model.failedParts) จาก \(model.totalParts) ส่วน รายการอาจไม่ครบ"
        }
        return nil
    }

    private var analyzing: some View {
        VStack(spacing: 20) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 320)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .opacity(0.6)
            ProgressView()
                .controlSize(.large)
            Text(model.isSecondAttempt ? "อ่านยาก กำลังลองอีกครั้งอย่างละเอียด…" : "กำลังอ่านเมนู…")
                .font(.headline)
            Text(
                model.totalParts > 1
                    ? "อ่านแล้ว \(model.completedParts) จาก \(model.totalParts) ส่วน"
                    : "ปกติใช้เวลาไม่ถึงหนึ่งนาที"
            )
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding(24)
    }

    private var tooSmall: some View {
        ContentUnavailableView {
            Label("รูปเล็กเกินไป", systemImage: "arrow.up.left.and.arrow.down.right")
        } description: {
            Text(
                "รูปนี้มีขนาด \(Int(model.sourcePixelSize.width))×\(Int(model.sourcePixelSize.height)) พิกเซล ตัวหนังสือน่าจะเล็กเกินกว่าจะอ่านออก ลองใช้รูปที่ถ่ายจากกล้องโดยตรง"
            )
        } actions: {
            Button("เลือกรูปใหม่") { dismiss() }
                .buttonStyle(.borderedProminent)
            Button("ลองอ่านรูปนี้") { Task { await model.retry() } }
        }
    }
}

/// Shown when the page was read but no dish could be made out.
struct UnreadableView: View {
    let image: UIImage
    let notes: String
    let onRetake: () -> Void

    private let tips = [
        ("viewfinder", "ถ่ายทีละหน้า ให้เมนูเต็มกรอบ"),
        ("sun.max", "เลี่ยงแสงสะท้อนจากแผ่นพลาสติกหรือกระจก"),
        ("camera.macro", "ถ้าตัวหนังสือเล็กหรือเป็นลายมือ ถ่ายใกล้ขึ้นทีละส่วน"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                VStack(spacing: 6) {
                    Text("อ่านเมนูนี้ไม่ออก")
                        .font(.title2.bold())
                    Text("แอปไม่เดารายการที่อ่านไม่ชัด เพื่อไม่ให้สั่งผิด")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(tips, id: \.1) { icon, text in
                        Label(text, systemImage: icon)
                            .font(.callout)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16))

                Button(action: onRetake) {
                    Label("ถ่ายใหม่", systemImage: "camera.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .controlSize(.large)

                if !notes.isEmpty {
                    DisclosureGroup("สิ่งที่โมเดลเห็นในรูป") {
                        Text(notes)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.top, 6)
                    }
                    .font(.footnote)
                }
            }
            .padding(24)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
        }
        .background(Color(.systemGroupedBackground))
    }
}

#Preview {
    NavigationStack {
        UnreadableView(image: MenuResult.preview.pageImage, notes: "เมนูลายมือ ถ่ายมาเล็กและเบลอ") {}
    }
}
