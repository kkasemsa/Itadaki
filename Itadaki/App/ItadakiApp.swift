import SwiftData
import SwiftUI

@main
struct ItadakiApp: App {
    var body: some Scene {
        WindowGroup {
            CaptureView()
                .tint(Theme.accent)
        }
        .modelContainer(for: [SavedMenu.self, SavedPage.self])
    }
}
