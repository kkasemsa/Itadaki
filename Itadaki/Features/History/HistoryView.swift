import SwiftData
import SwiftUI

/// Saved menus, newest first. Opening one needs no network.
struct HistoryView: View {
    @Query(sort: \SavedMenu.createdAt, order: .reverse) private var menus: [SavedMenu]
    @Environment(\.modelContext) private var modelContext
    @State private var renaming: SavedMenu?
    @State private var newTitle = ""

    var body: some View {
        Group {
            if menus.isEmpty {
                ContentUnavailableView(
                    "ยังไม่มีเมนูที่บันทึกไว้",
                    systemImage: "clock",
                    description: Text("เมนูที่อ่านสำเร็จจะถูกบันทึกไว้ที่นี่โดยอัตโนมัติ"))
            } else {
                List {
                    ForEach(menus) { menu in
                        NavigationLink(value: menu) {
                            HistoryRow(menu: menu)
                        }
                        .listRowBackground(Theme.card)
                        .contextMenu {
                            Button("เปลี่ยนชื่อ", systemImage: "pencil") {
                                newTitle = menu.title
                                renaming = menu
                            }
                            Button("ลบ", systemImage: "trash", role: .destructive) { delete(menu) }
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets { delete(menus[index]) }
                    }
                }
                .scrollContentBackground(.hidden)
            }
        }
        .paperBackground()
        .navigationTitle("ประวัติเมนู")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.paper, for: .navigationBar)
        .navigationDestination(for: SavedMenu.self) { menu in
            SavedMenuView(menu: menu)
        }
        .alert("เปลี่ยนชื่อเมนู", isPresented: isRenaming) {
            TextField("ชื่อเมนู", text: $newTitle)
            Button("บันทึก") {
                let title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                if !title.isEmpty { renaming?.title = title }
                renaming = nil
            }
            Button("ยกเลิก", role: .cancel) { renaming = nil }
        }
    }

    private var isRenaming: Binding<Bool> {
        Binding(get: { renaming != nil }, set: { if !$0 { renaming = nil } })
    }

    private func delete(_ menu: SavedMenu) {
        modelContext.delete(menu)
        try? modelContext.save()
    }
}

private struct HistoryRow: View {
    let menu: SavedMenu

    var body: some View {
        HStack(spacing: 14) {
            Color.clear
                .frame(width: 56, height: 72)
                .overlay {
                    if let data = menu.thumbnail, let image = UIImage(data: data) {
                        Image(uiImage: image).resizable().scaledToFill()
                    } else {
                        Theme.paper
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Theme.hairline, lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 4) {
                Text(menu.title)
                    .font(.headline)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(2)
                Text(
                    menu.createdAt.formatted(
                        Date.FormatStyle(date: .abbreviated, time: .shortened)
                            .locale(Locale(identifier: "th_TH")))
                )
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var detail: String {
        let pages = menu.pages.count
        return pages > 1 ? "\(pages) หน้า · \(menu.dishCount) รายการ" : "\(menu.dishCount) รายการ"
    }
}

/// A saved menu, shown with the same list as a fresh scan.
struct SavedMenuView: View {
    let menu: SavedMenu
    @State private var pages: [PageState]?
    @State private var order = Order()
    @State private var selectedPage = 0

    var body: some View {
        Group {
            if let pages {
                VStack(spacing: 0) {
                    if pages.count > 1 {
                        PageStrip(pages: pages, selection: $selectedPage)
                    }
                    if pages.indices.contains(selectedPage), let result = pages[selectedPage].result {
                        MenuPageView(
                            result: result, order: $order,
                            allDishes: pages.flatMap { $0.result?.items.map(\.dish) ?? [] }
                        )
                        .id(selectedPage)
                    } else {
                        ContentUnavailableView("เปิดเมนูนี้ไม่ได้", systemImage: "exclamationmark.triangle")
                    }
                }
            } else {
                ProgressView().controlSize(.large)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .paperBackground()
        .navigationTitle(menu.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Theme.paper, for: .navigationBar)
        .task {
            if pages == nil { pages = await HistoryStore.load(menu) }
        }
    }
}
