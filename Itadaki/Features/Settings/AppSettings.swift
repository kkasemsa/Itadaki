import Foundation
import SwiftUI

/// UserDefaults keys and the analyzer factory that reads them.
enum AppSettings {
    static let modelKey = "claudeModel"
    /// Baht per 100 yen, the way Thai exchange booths quote it. 0 = not set.
    static let bahtPer100YenKey = "bahtPer100Yen"
    static let sampleModeKey = "sampleMode"
    /// How many strips a page is cut into before upload (1–3).
    static let stripsKey = "pageStrips"
    static let defaultStrips = 2

    static var hasAPIKey: Bool {
        !(KeychainStore.string(for: KeychainStore.apiKeyAccount) ?? "").isEmpty
    }

    static var isSampleMode: Bool {
        UserDefaults.standard.bool(forKey: sampleModeKey)
    }

    /// Strips per page. Sample mode returns the same fixture for every request, so it
    /// always reads the page whole.
    static var strips: Int {
        if isSampleMode { return 1 }
        let stored = UserDefaults.standard.integer(forKey: stripsKey)
        return stored == 0 ? defaultStrips : min(max(stored, 1), 3)
    }

    static func makeAnalyzer(effort: AnalysisEffort) -> MenuAnalyzer {
        if isSampleMode { return MockMenuAnalyzer(delay: .seconds(1)) }
        return ClaudeMenuAnalyzer(
            apiKey: KeychainStore.string(for: KeychainStore.apiKeyAccount) ?? "",
            model: UserDefaults.standard.string(forKey: modelKey) ?? ClaudeMenuAnalyzer.defaultModel,
            effort: effort
        )
    }
}
