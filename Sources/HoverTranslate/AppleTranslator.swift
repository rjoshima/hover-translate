import Foundation
import Translation

@MainActor final class AppleTranslator {
    static let source = Locale.Language(identifier: "en")
    static let target = Locale.Language(identifier: "ja")
    private var session: TranslationSession?

    func isInstalled() async -> Bool {
        await LanguageAvailability().status(from: Self.source, to: Self.target) == .installed
    }
    func translate(_ text: String) async throws -> String {
        guard await isInstalled() else { throw LocalError.languagesMissing }
        try Task.checkCancellation()
        let active = TranslationSession(installedSource: Self.source, target: Self.target)
        session = active
        defer { if session === active { session = nil } }
        let response = try await active.translate(text)
        try Task.checkCancellation()
        return response.targetText
    }
    func cancel() { session?.cancel(); session = nil }

    enum LocalError: LocalizedError {
        case languagesMissing
        var errorDescription: String? {
            "設定で「Apple翻訳を準備」を押して、英語と日本語をダウンロードしてください。AIへは自動送信しません。"
        }
    }
}

enum TranslationEngine: String {
    case apple, openRouter
    var label: String { self == .apple ? "Apple · 端末内" : "AI · OpenRouter" }
}
