import AppKit
import SwiftUI
import HoverCore

@MainActor final class AppModel: ObservableObject {
    @Published var status = "APIキーを設定すると使えます。"
    @Published var hasKey: Bool
    @Published var translated = ""
    @Published var demoBusy = false
    @Published var targets: [String]
    private var cache = TranslationCache()
    private var task: Task<Void, Never>?
    private var generation = 0
    private var anchor = NSPoint.zero
    private var bubble: NSPanel?
    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.urlCache = nil
        config.httpCookieStorage = nil
        return URLSession(configuration: config, delegate: NoRedirectDelegate(), delegateQueue: nil)
    }()

    init() {
        let defaults = UserDefaults.standard
        hasKey = KeyStore.isConfigured()
        let claude = "com.anthropic.claudefordesktop"
        var configured = defaults.stringArray(forKey: "targets") ?? ["com.openai.codex", claude]
        if !defaults.bool(forKey: "claudeTargetAddedV1") {
            if !configured.contains(claude) { configured.append(claude) }
            defaults.set(configured, forKey: "targets")
            defaults.set(true, forKey: "claudeTargetAddedV1")
        }
        targets = configured
        if hasKey { status = "英文を選択して、メニューバーの「訳」を押してください。" }
    }

    var remaining: Int {
        refreshDay()
        return max(0, 500 - UserDefaults.standard.integer(forKey: "calls"))
    }
    func refreshDay() {
        let day = ISO8601DateFormatter().string(from: Calendar.current.startOfDay(for: Date()))
        if UserDefaults.standard.string(forKey: "day") != day {
            UserDefaults.standard.set(day, forKey: "day")
            UserDefaults.standard.set(0, forKey: "calls")
        }
    }
    @discardableResult func saveKey(_ key: String) -> Bool {
        let value = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.hasPrefix("sk-or-"), value.count > 20 else {
            status = "OpenRouterのAPIキーを入力してください。"; return false
        }
        stop()
        do {
            try KeyStore.save(value)
            cache.clear()
            hasKey = true
            UserDefaults.standard.set(true, forKey: "hasKey")
            status = "キーを保存しました。次回から再入力は不要です。"
            return true
        } catch { status = error.localizedDescription; return false }
    }
    func deleteKey() {
        stop()
        do { try KeyStore.delete() } catch { status = error.localizedDescription; return }
        hasKey = false
        UserDefaults.standard.set(false, forKey: "hasKey")
        status = "APIキーを削除しました。"
    }
    func stop() {
        dismiss()
        cache.clear()
        status = "英文を選択して、メニューバーの「訳」を押してください。"
    }
    func translateSelection(at point: NSPoint) {
        dismiss()
        anchor = point
        guard hasKey else { showBubble(TranslationError.missingKey.localizedDescription, loading: false); return }
        guard AXIsProcessTrusted() else {
            status = "Macのアクセシビリティ設定でHover Translateを許可してください。"
            showBubble(status, loading: false); return
        }
        guard let source = NSWorkspace.shared.frontmostApplication,
              let bundle = source.bundleIdentifier, targets.contains(bundle),
              source.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            status = "対象アプリの英文を選択してから「訳」を押してください。"
            showBubble(status, loading: false); return
        }
        let sourcePID = source.processIdentifier
        TextReader.prepare(pid: sourcePID, bundleID: bundle)
        let revision = generation
        task = Task {
            var selected = TextReader.selectedText(pid: sourcePID)
            if selected == nil {
                // One local retry for Electron's accessibility initialization; no automatic network retry.
                try? await Task.sleep(for: .milliseconds(200))
                guard !Task.isCancelled, revision == generation,
                      NSWorkspace.shared.frontmostApplication?.processIdentifier == sourcePID else { return }
                selected = TextReader.selectedText(pid: sourcePID)
            }
            guard let selected else {
                status = "選択した英文を読み取れませんでした。短い文章を選択してから、もう一度「訳」を押してください。"
                showBubble(status, loading: false); return
            }
            guard let text = TextPolicy.candidate(selected) else {
                status = TranslationError.unsafeText.localizedDescription
                showBubble(status, loading: false); return
            }
            showBubble("翻訳中…", loading: true)
            status = "選択した文章を翻訳中…"
            do {
                let result = try await translate(text)
                guard !Task.isCancelled, revision == generation else { return }
                showBubble(result, loading: false)
                status = "翻訳しました。本日あと\(remaining)回。"
            } catch {
                guard !Task.isCancelled, revision == generation else { return }
                status = error.localizedDescription
                showBubble(status, loading: false)
            }
        }
    }
    func openPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
    func toggleTarget(_ id: String) {
        if targets.contains(id) { targets.removeAll { $0 == id } } else { targets.append(id) }
        UserDefaults.standard.set(targets, forKey: "targets")
        dismiss()
    }
    func demo() {
        guard !demoBusy else { return }
        stop()
        demoBusy = true
        translated = ""
        task?.cancel()
        task = Task {
            defer { demoBusy = false }
            do {
                translated = try await translate("Hover over an English sentence to see the Japanese translation.", useCache: false)
                status = "接続テスト成功。日本語の訳を確認してください。"
            } catch { status = error.localizedDescription }
        }
    }
    private func translate(_ text: String, useCache: Bool = true) async throws -> String {
        if useCache, let cached = cache[text] { return cached }
        guard remaining > 0 else { throw TranslationError.dailyLimit }
        guard let key = try KeyStore.read() else { throw TranslationError.missingKey }
        try Task.checkCancellation()
        let request = try OpenRouter.request(text: text, key: key)
        // Count attempts before sending: failures and cancellation never create unlimited retries.
        UserDefaults.standard.set(500 - remaining + 1, forKey: "calls")
        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        let result = try OpenRouter.parse(data, status: (response as? HTTPURLResponse)?.statusCode ?? 0)
        cache.insert(result, for: text)
        return result
    }
    private func dismiss() {
        generation += 1
        task?.cancel(); task = nil
        bubble?.orderOut(nil)
    }
    private func showBubble(_ text: String, loading: Bool) {
        if bubble == nil {
            let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.level = .floating
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.hasShadow = true
            panel.hidesOnDeactivate = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            bubble = panel
        }
        guard let bubble else { return }
        let screen = NSScreen.screens.first { $0.frame.contains(anchor) } ?? NSScreen.main!
        let frame = screen.visibleFrame
        let width = min(390, frame.width - 24)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 5
        let measured = (text as NSString).boundingRect(
            with: NSSize(width: width - 32, height: 10_000),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: NSFont.systemFont(ofSize: 14), .paragraphStyle: paragraph]
        ).height
        let height = min(max(ceil(measured) + 70, 100), min(430, frame.height - 24))
        let view = NSHostingView(rootView: BubbleView(text: text, loading: loading, width: width, height: height, onClose: { [weak self] in self?.dismiss() }))
        let x = max(frame.minX + 12, min(anchor.x + 12, frame.maxX - width - 12))
        let y = max(frame.minY + 12, min(anchor.y - height - 14, frame.maxY - height - 12))
        bubble.contentView = view
        bubble.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
        bubble.orderFrontRegardless()
    }
}

struct BubbleView: View {
    let text: String
    let loading: Bool
    let width: CGFloat
    let height: CGFloat
    let onClose: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "character.bubble.fill").foregroundStyle(.mint)
                Text("日本語").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                if loading { ProgressView().controlSize(.mini) }
                Button(action: onClose) { Image(systemName: "xmark") }
                    .buttonStyle(.plain).accessibilityLabel("翻訳を閉じる")
            }
            ScrollView {
                Text(text).font(.system(size: 14)).lineSpacing(5)
                    .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(16).frame(width: width, height: height)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.primary.opacity(0.10)))
    }
}
