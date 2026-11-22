import PhotosUI
import SwiftUI

/// Home screen: take or pick one menu photo, then hand it to the scan screen.
struct CaptureView: View {
    @State private var pickedItem: PhotosPickerItem?
    @State private var showCamera = false
    @State private var showSettings = false
    @State private var scanInput: ScanInput?
    @State private var canAnalyze = AppSettings.hasAPIKey || AppSettings.isSampleMode
    @State private var loadFailed = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                Image(systemName: "fork.knife.circle.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.tint)
                VStack(spacing: 8) {
                    Text("Itadaki").font(.largeTitle.bold())
                    Text("ถ่ายรูปเมนูภาษาญี่ปุ่น แล้วอ่านเป็นภาษาไทย")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                Spacer()

                if !canAnalyze {
                    Button {
                        showSettings = true
                    } label: {
                        Label("ใส่ Claude API key ในตั้งค่าก่อนเริ่มใช้งาน", systemImage: "key.fill")
                            .font(.callout)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.orange)
                }

                VStack(spacing: 12) {
                    Button {
                        showCamera = true
                    } label: {
                        Label("ถ่ายรูปเมนู", systemImage: "camera.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!CameraPicker.isAvailable)

                    PhotosPicker(selection: $pickedItem, matching: .images) {
                        Label("เลือกรูปจากคลัง", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .controlSize(.large)
            }
            .padding(24)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Label("ตั้งค่า", systemImage: "gearshape")
                    }
                }
            }
            .navigationDestination(item: $scanInput) { input in
                ScanView(image: input.image)
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { image in
                    showCamera = false
                    if let image { scanInput = ScanInput(image: image) }
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showSettings, onDismiss: refreshCanAnalyze) {
                SettingsView()
            }
            .alert("เปิดรูปนี้ไม่ได้", isPresented: $loadFailed) {
                Button("ตกลง", role: .cancel) {}
            }
            .onChange(of: pickedItem) { _, item in
                guard let item else { return }
                pickedItem = nil
                Task { await load(item) }
            }
        }
    }

    private func refreshCanAnalyze() {
        canAnalyze = AppSettings.hasAPIKey || AppSettings.isSampleMode
    }

    private func load(_ item: PhotosPickerItem) async {
        if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
            scanInput = ScanInput(image: image)
        } else {
            loadFailed = true
        }
    }
}

/// One photo on its way to analysis.
struct ScanInput: Identifiable, Hashable {
    let id = UUID()
    let image: UIImage

    static func == (lhs: ScanInput, rhs: ScanInput) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

#Preview {
    CaptureView()
}
