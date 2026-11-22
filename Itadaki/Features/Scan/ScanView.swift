import SwiftUI

/// Analyzes one photo and shows progress, an error with retry, or the dish list.
struct ScanView: View {
    @State private var model: ScanViewModel
    private let image: UIImage

    init(image: UIImage, makeAnalyzer: @escaping () -> MenuAnalyzer = AppSettings.makeAnalyzer) {
        self.image = image
        _model = State(initialValue: ScanViewModel(image: image, makeAnalyzer: makeAnalyzer))
    }

    var body: some View {
        Group {
            switch model.state {
            case .analyzing:
                analyzing
            case .done(let result):
                DishListView(result: result)
            case .failed(let message):
                ContentUnavailableView {
                    Label("อ่านเมนูไม่สำเร็จ", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(message)
                } actions: {
                    Button("ลองใหม่") { Task { await model.retry() } }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
        .navigationTitle("เมนู")
        .navigationBarTitleDisplayMode(.inline)
        .task { await model.start() }
    }

    private var analyzing: some View {
        VStack(spacing: 20) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 320)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .opacity(0.6)
            ProgressView()
                .controlSize(.large)
            Text("กำลังอ่านเมนู…")
                .font(.headline)
            Text("ปกติใช้เวลาไม่ถึงหนึ่งนาที")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(24)
    }
}
