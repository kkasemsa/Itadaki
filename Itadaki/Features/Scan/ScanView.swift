import SwiftUI

/// Analyzes one or more menu photos and shows, page by page, progress, an error
/// with retry, or the dish list.
struct ScanView: View {
    @State private var model: ScanViewModel
    @State private var order = Order()
    @State private var selectedPage = 0
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    /// Set once the finished scan has been written to history.
    @State private var isSaved = false

    init(images: [UIImage]) {
        _model = State(initialValue: ScanViewModel(images: images))
    }

    var body: some View {
        Group {
            switch model.phase {
            case .tooSmall:
                tooSmall
            case .failed(let message):
                failure(message)
            case .analyzing, .done:
                VStack(spacing: 0) {
                    if model.pages.count > 1 {
                        PageStrip(pages: model.pages, selection: $selectedPage)
                    }
                    if let page = currentPage {
                        pageContent(page)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .id(page.id)
                    } else {
                        analyzing(image: model.sourceImages.first)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .paperBackground()
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.paper, for: .navigationBar)
        .toolbar {
            if isSaved {
                ToolbarItem(placement: .topBarTrailing) {
                    Label("บันทึกในประวัติแล้ว", systemImage: "checkmark.circle.fill")
                        .labelStyle(.iconOnly)
                        .foregroundStyle(Theme.accent)
                }
            }
        }
        .task { await model.start() }
        .onChange(of: model.phase) { _, phase in
            // Keep every finished scan so it can be reopened without another API call.
            guard phase == .done, !isSaved else { return }
            Task {
                if await HistoryStore.save(pages: model.pages, in: modelContext) != nil {
                    isSaved = true
                }
            }
        }
    }

    private var title: String {
        model.pages.count > 1 ? "เมนู · หน้า \(selectedPage + 1)/\(model.pages.count)" : "เมนู"
    }

    private var currentPage: PageState? {
        model.pages.indices.contains(selectedPage) ? model.pages[selectedPage] : model.pages.first
    }

    @ViewBuilder
    private func pageContent(_ page: PageState) -> some View {
        if let result = page.result, !result.items.isEmpty {
            MenuPageView(
                result: result, order: $order, progress: progressText(page), allDishes: model.allDishes)
        } else {
            switch page.status {
            case .reading:
                analyzing(image: page.image)
            case .done:
                UnreadableView(image: page.image, notes: page.result?.notes ?? "") { dismiss() }
            case .failed(let message):
                failure(message)
            }
        }
    }

    /// Status line shown under a page's list while more of it is still being read.
    private func progressText(_ page: PageState) -> String? {
        if page.status == .reading { return "กำลังอ่านส่วนที่เหลือของหน้านี้…" }
        if page.failedParts > 0 { return "อ่านไม่สำเร็จ \(page.failedParts) ส่วนของหน้านี้ รายการอาจไม่ครบ" }
        return nil
    }

    private func failure(_ message: String) -> some View {
        ContentUnavailableView {
            Label("อ่านเมนูไม่สำเร็จ", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("ลองใหม่") { Task { await model.retry() } }
                .buttonStyle(.borderedProminent)
        }
    }

    private func analyzing(image: UIImage?) -> some View {
        VStack(spacing: 22) {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .overlay { ScanBeam() }
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .strokeBorder(Theme.hairline, lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.12), radius: 18, y: 8)
                    .frame(maxHeight: 380)
            }
            Text("読み取り中")
                .font(Theme.mincho(15, relativeTo: .footnote))
                .foregroundStyle(Theme.accent)
                .environment(\.locale, Locale(identifier: "ja"))
            Text(model.isSecondAttempt ? "อ่านยาก กำลังลองอีกครั้งอย่างละเอียด…" : "กำลังอ่านเมนู…")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.ink)
                .padding(.top, -12)
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
                "รูปนี้มีขนาด \(Int(model.firstPixelSize.width))×\(Int(model.firstPixelSize.height)) พิกเซล ตัวหนังสือน่าจะเล็กเกินกว่าจะอ่านออก ลองใช้รูปที่ถ่ายจากกล้องโดยตรง"
            )
        } actions: {
            Button("เลือกรูปใหม่") { dismiss() }
                .buttonStyle(.borderedProminent)
            Button("ลองอ่านรูปนี้") { Task { await model.retry() } }
        }
    }
}

/// Thumbnails of the scanned pages; tapping one shows that page's dishes.
struct PageStrip: View {
    let pages: [PageState]
    @Binding var selection: Int

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(pages) { page in
                    Button {
                        selection = page.id
                    } label: {
                        thumbnail(page)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("หน้า \(page.id + 1)")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Theme.paper)
        .overlay(alignment: .bottom) { Theme.hairline.frame(height: 1) }
    }

    private func thumbnail(_ page: PageState) -> some View {
        let isSelected = page.id == selection
        return VStack(spacing: 5) {
            Color.clear
                .frame(width: 58, height: 74)
                .overlay { Image(uiImage: page.image).resizable().scaledToFill() }
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(isSelected ? Theme.accent : Theme.hairline, lineWidth: isSelected ? 2.5 : 1)
                }
                .overlay { badge(page) }
                .opacity(isSelected ? 1 : 0.75)
            Text("หน้า \(page.id + 1)")
                .font(.caption2.weight(isSelected ? .bold : .regular))
                .foregroundStyle(isSelected ? Theme.accent : .secondary)
        }
    }

    /// Spinner while a page is being read, a warning if it failed, else its dish count.
    @ViewBuilder
    private func badge(_ page: PageState) -> some View {
        switch page.status {
        case .reading:
            ProgressView()
                .tint(.white)
                .frame(width: 30, height: 30)
                .background(.black.opacity(0.5), in: Circle())
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
                .frame(width: 30, height: 30)
                .background(.black.opacity(0.5), in: Circle())
        case .done:
            Text("\(page.dishCount)")
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(.white)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(Theme.accent, in: Capsule())
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(4)
        }
    }
}

/// A band of light sweeping down the photo while it is being read.
struct ScanBeam: View {
    @State private var atBottom = false

    var body: some View {
        GeometryReader { proxy in
            LinearGradient(
                colors: [.clear, Theme.accent.opacity(0.5), .white.opacity(0.7), .clear],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 90)
            .offset(y: atBottom ? proxy.size.height - 30 : -60)
            .onAppear {
                withAnimation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true)) {
                    atBottom = true
                }
            }
        }
        .background(Color.black.opacity(0.12))
        .allowsHitTesting(false)
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
        ("plus.magnifyingglass", "ถ้าตัวหนังสือเล็กหรือเป็นลายมือ ถ่ายใกล้ขึ้นทีละส่วน"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .saturation(0.4)
                    .shadow(color: .black.opacity(0.1), radius: 12, y: 6)

                VStack(spacing: 6) {
                    Text("読めません")
                        .font(Theme.mincho(15, relativeTo: .footnote))
                        .foregroundStyle(Theme.accent)
                        .environment(\.locale, Locale(identifier: "ja"))
                    Text("อ่านเมนูนี้ไม่ออก")
                        .font(.title2.bold())
                        .foregroundStyle(Theme.ink)
                    Text("แอปไม่เดารายการที่อ่านไม่ชัด เพื่อไม่ให้สั่งผิด")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 14) {
                    ForEach(tips, id: \.1) { icon, text in
                        Label {
                            Text(text).foregroundStyle(Theme.ink)
                        } icon: {
                            Image(systemName: icon).foregroundStyle(Theme.accent)
                        }
                        .font(.callout)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(18)
                .paperCard()

                Button(action: onRetake) {
                    Label("ถ่ายใหม่", systemImage: "camera.fill")
                }
                .buttonStyle(PrimaryButtonStyle())

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
        .paperBackground()
    }
}

#Preview {
    NavigationStack {
        UnreadableView(image: MenuResult.preview.pageImage, notes: "เมนูลายมือ ถ่ายมาเล็กและเบลอ") {}
    }
}
