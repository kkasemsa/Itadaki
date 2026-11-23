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
            VStack(spacing: 0) {
                Spacer(minLength: 24)

                VStack(spacing: 22) {
                    SealEmblem()
                    VStack(spacing: 10) {
                        Text("Itadaki")
                            .font(.system(size: 46, weight: .bold, design: .serif))
                            .foregroundStyle(Theme.ink)
                        HStack(spacing: 10) {
                            Rectangle().fill(Theme.accent).frame(width: 22, height: 1.5)
                            Text("いただきます")
                                .font(Theme.mincho(17, relativeTo: .body))
                                .foregroundStyle(Theme.accent)
                                .environment(\.locale, Locale(identifier: "ja"))
                            Rectangle().fill(Theme.accent).frame(width: 22, height: 1.5)
                        }
                        Text("ถ่ายรูปเมนูภาษาญี่ปุ่น\nอ่านเป็นภาษาไทยได้ทันที")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 6)
                    }
                }

                Spacer(minLength: 24)

                VStack(spacing: 12) {
                    if !canAnalyze {
                        Button {
                            showSettings = true
                        } label: {
                            Label("ใส่ Claude API key ในตั้งค่าก่อนเริ่มใช้งาน", systemImage: "key.fill")
                                .font(.footnote.weight(.medium))
                                .foregroundStyle(Theme.accent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .background(Theme.accent.opacity(0.1), in: Capsule())
                        }
                        .padding(.bottom, 4)
                    }

                    Button {
                        showCamera = true
                    } label: {
                        Label("ถ่ายรูปเมนู", systemImage: "camera.fill")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!CameraPicker.isAvailable)
                    .opacity(CameraPicker.isAvailable ? 1 : 0.45)

                    PhotosPicker(selection: $pickedItem, matching: .images) {
                        Label("เลือกรูปจากคลัง", systemImage: "photo.on.rectangle")
                    }
                    .buttonStyle(SecondaryButtonStyle())

                    Text("ถ่ายทีละหน้า ให้ตัวหนังสือชัดและไม่มีแสงสะท้อน")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.top, 6)
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 20)
            .frame(maxWidth: 520)
            .frame(maxWidth: .infinity)
            .paperBackground(pattern: true)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Label("ตั้งค่า", systemImage: "gearshape")
                    }
                    .tint(Theme.ink)
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
                    .tint(Theme.accent)
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
        .tint(Theme.accent)
}
