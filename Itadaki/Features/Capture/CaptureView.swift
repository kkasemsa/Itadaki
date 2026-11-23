import PhotosUI
import SwiftUI

/// Home screen: photograph menu pages one after another, or pick several photos,
/// then hand them to the scan screen.
struct CaptureView: View {
    @State private var pickedItems: [PhotosPickerItem] = []
    /// Pages photographed so far and waiting to be read.
    @State private var staged: [UIImage] = []
    @State private var isLoading = false
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

                    if staged.isEmpty {
                        Button {
                            showCamera = true
                        } label: {
                            Label("ถ่ายรูปเมนู", systemImage: "camera.fill")
                        }
                        .buttonStyle(PrimaryButtonStyle())
                        .disabled(!CameraPicker.isAvailable)
                        .opacity(CameraPicker.isAvailable ? 1 : 0.45)

                        PhotosPicker(
                            selection: $pickedItems, maxSelectionCount: ScanViewModel.maximumPages,
                            selectionBehavior: .ordered, matching: .images
                        ) {
                            Label("เลือกรูปจากคลัง", systemImage: "photo.on.rectangle")
                        }
                        .buttonStyle(SecondaryButtonStyle())

                        Text("เมนูหลายหน้า ถ่ายต่อกันหรือเลือกหลายรูปได้ สูงสุด \(ScanViewModel.maximumPages) หน้า")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.top, 6)
                    } else {
                        StagedPages(images: $staged)

                        Button {
                            let images = staged
                            staged = []
                            scanInput = ScanInput(images: images)
                        } label: {
                            Label("อ่านเมนู \(staged.count) หน้า", systemImage: "text.viewfinder")
                        }
                        .buttonStyle(PrimaryButtonStyle())

                        Button {
                            showCamera = true
                        } label: {
                            Label("ถ่ายหน้าถัดไป", systemImage: "camera.fill")
                        }
                        .buttonStyle(SecondaryButtonStyle())
                        .disabled(staged.count >= ScanViewModel.maximumPages)
                        .opacity(staged.count >= ScanViewModel.maximumPages ? 0.45 : 1)
                    }
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
                ScanView(images: input.images)
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraPicker { image in
                    showCamera = false
                    if let image { Task { await stage(image) } }
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
            .onChange(of: pickedItems) { _, items in
                guard !items.isEmpty else { return }
                pickedItems = []
                Task { await load(items) }
            }
            .overlay {
                if isLoading {
                    ProgressView()
                        .controlSize(.large)
                        .padding(28)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
                }
            }
        }
    }

    private func refreshCanAnalyze() {
        canAnalyze = AppSettings.hasAPIKey || AppSettings.isSampleMode
    }

    /// Adds a camera shot to the waiting pages, shrunk to working size so several
    /// full-resolution photos are never held in memory at once.
    private func stage(_ image: UIImage) async {
        isLoading = true
        defer { isLoading = false }
        staged.append(await Self.shrink(image))
    }

    /// Loads the picked photos in the order chosen and starts reading them.
    private func load(_ items: [PhotosPickerItem]) async {
        isLoading = true
        defer { isLoading = false }
        var images: [UIImage] = []
        for item in items {
            if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                images.append(await Self.shrink(image))
            }
        }
        if images.isEmpty {
            loadFailed = true
        } else {
            scanInput = ScanInput(images: images)
        }
    }

    private static func shrink(_ image: UIImage) async -> UIImage {
        await Task.detached(priority: .userInitiated) {
            ImageCropper.normalized(image, maxLongEdge: ImageCropper.workingLongEdge)
        }.value
    }
}

/// Row of photographed pages waiting to be read, each removable.
struct StagedPages: View {
    @Binding var images: [UIImage]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(Array(images.enumerated()), id: \.offset) { index, image in
                    Color.clear
                        .frame(width: 72, height: 96)
                        .overlay { Image(uiImage: image).resizable().scaledToFill() }
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(alignment: .bottomLeading) {
                            Text("\(index + 1)")
                                .font(.caption.weight(.bold).monospacedDigit())
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Theme.accent, in: Capsule())
                                .padding(5)
                        }
                        .overlay(alignment: .topTrailing) {
                            Button {
                                images.remove(at: index)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 22, height: 22)
                                    .background(.black.opacity(0.6), in: Circle())
                            }
                            .accessibilityLabel("ลบหน้า \(index + 1)")
                            .padding(4)
                        }
                        .shadow(color: .black.opacity(0.12), radius: 6, y: 3)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 2)
        }
        .padding(.bottom, 4)
    }
}

/// The photos on their way to analysis, one per menu page.
struct ScanInput: Identifiable, Hashable {
    let id = UUID()
    let images: [UIImage]

    static func == (lhs: ScanInput, rhs: ScanInput) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

#Preview {
    CaptureView()
        .tint(Theme.accent)
}
