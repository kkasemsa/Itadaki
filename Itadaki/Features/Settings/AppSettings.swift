import Foundation

/// UserDefaults keys and the analyzer factory that reads them.
enum AppSettings {
    static let modelKey = "claudeModel"
    static let bahtPerYenKey = "bahtPerYen"
    static let sampleModeKey = "sampleMode"

    static var hasAPIKey: Bool {
        !(KeychainStore.string(for: KeychainStore.apiKeyAccount) ?? "").isEmpty
    }

    static var isSampleMode: Bool {
        UserDefaults.standard.bool(forKey: sampleModeKey)
    }

    static func makeAnalyzer() -> MenuAnalyzer {
        if isSampleMode { return MockMenuAnalyzer(delay: .seconds(1)) }
        return ClaudeMenuAnalyzer(
            apiKey: KeychainStore.string(for: KeychainStore.apiKeyAccount) ?? "",
            model: UserDefaults.standard.string(forKey: modelKey) ?? ClaudeMenuAnalyzer.defaultModel
        )
    }
}
