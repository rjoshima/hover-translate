import AppKit
import SwiftUI
import HoverCore

@MainActor final class AppModel: ObservableObject {
    @Published var enabled = false
    @Published var status = "APIキーを設定すると使えます。"
    @Published var hasKey = UserDefaults.standard.bool(forKey: "hasKey")
    @Published var translated = ""
    @Published var demoBusy = false
    @Published var targets: [String] = UserDefaults.standard.stringArray(forKey: "targets") ?? ["com.openai.codex"]
    private var gate = HoverGate()
    private var timer: Timer?
    private var cache = TranslationCache()
    private var task: Task<Void, Never>?
    private var generation = 0
    private var activePID: pid_t = 0
    private var lastPoint = NSPoint.zero
    private var lastRequest = Date.distantPast
    private var anchor = NSPoint.zero
    private var bubble: NSPanel?
    private let session: URLSession = {
        let config = URLSessionConfiguration.ephemeral
        config.urlCache = nil
        config.httpCookieStorage = nil
        return URLSession(configuration: config)
    }()

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
    func saveKey(_ key: String) {
        let value = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.hasPrefix("sk-or-"), value.count > 20 else {
            status = "OpenRouterのAPIキーを入力してください。"; return
        }
        do {
            try KeyStore.save(value)
            cache.clear()
            hasKey = true
            UserDefaults.standard.set(true, forKey: "hasKey")
            status = "キーを保存しました。接続テストができます。"
        } catch { status = error.localizedDescription }
    }
    func deleteKey() {
        stop()
        do { try KeyStore.delete() } catch { status = error.localizedDescription; return }
        hasKey = false
        UserDefaults.standard.set(false, forKey: "hasKey")
        status = "APIキーを削除しました。"
    }
    func start() {
        guard hasKey else { status = "先にAPIキーを保存してください。"; return }
        guard AXIsProcessTrusted() else {
            status = "Macのアクセシビリティ設定でHover Translateを許可してください。"; return
        }
        enabled = true
        gate.reset()
        status = "英文の上で0.7秒止めると翻訳します。"
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }
    func stop() {
        enabled = false
        timer?.invalidate(); timer = nil
        dismiss()
        cache.clear()
        status = "停止中"
    }
    func openPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        _ = AXIsProcessTrustedWithOptions(options as CFDictionary)
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }
    func toggleTarget(_ id: String) {
        if targets.contains(id) { targets.removeAll { $0 == id } } else { targets.append(id) }
        UserDefaults.standard.set(targets, forKey: "targets")
        dismiss(); gate.reset()
    }
    func demo() {
        guard !demoBusy else { return }
        if enabled { stop() }
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
        guard let key = KeyStore.read() else { throw TranslationError.missingKey }
        let request = try OpenRouter.request(text: text, key: key)
        // Count attempts before sending: failures and cancellation never create unlimited retries.
        UserDefaults.standard.set(500 - remaining + 1, forKey: "calls")
        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        let result = try OpenRouter.parse(data, status: (response as? HTTPURLResponse)?.statusCode ?? 0)
        cache.insert(result, for: text)
        return result
    }
    private func tick() {
        guard enabled, AXIsProcessTrusted(), let app = NSWorkspace.shared.frontmostApplication,
              let bundle = app.bundleIdentifier, targets.contains(bundle),
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier else {
            dismiss(); gate.reset(); return
        }
        let point = NSEvent.mouseLocation
        if let bubble, bubble.isVisible, bubble.frame.insetBy(dx: -6, dy: -6).contains(point) { return }
        if app.processIdentifier != activePID {
            dismiss(); gate.reset(); activePID = app.processIdentifier
        }
        if hypot(point.x - lastPoint.x, point.y - lastPoint.y) > 5 || NSEvent.pressedMouseButtons != 0 {
            dismiss(); gate.reset(); lastPoint = point
        }
        guard NSEvent.pressedMouseButtons == 0,
              gate.ready(x: point.x, y: point.y, now: Date.timeIntervalSinceReferenceDate),
              Date().timeIntervalSince(lastRequest) > 1.2 else { return }
        // AppKit coordinates have a bottom-left origin; Accessibility uses top-left on the main display.
        let top = NSScreen.screens.first?.frame.maxY ?? 0
        let axPoint = CGPoint(x: point.x, y: top - point.y)
        guard let text = TextReader.text(at: axPoint, pid: app.processIdentifier) else {
            status = "ここでは英文を取得できません。別の英文にカーソルを合わせてください。"; return
        }
        anchor = point
        lastRequest = Date()
        generation += 1
        let revision = generation
        showBubble("翻訳中…", loading: true)
        task = Task {
            do {
                let result = try await translate(text)
                guard !Task.isCancelled, revision == generation, enabled,
                      NSWorkspace.shared.frontmostApplication?.processIdentifier == activePID else { return }
                showBubble(result, loading: false)
                status = "翻訳しました。本日あと\(remaining)回。"
            } catch {
                guard !Task.isCancelled, revision == generation else { return }
                showBubble(error.localizedDescription, loading: false)
                status = error.localizedDescription
            }
        }
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
        let view = NSHostingView(rootView: BubbleView(text: text, loading: loading))
        let size = view.fittingSize
        let screen = NSScreen.screens.first { $0.frame.contains(anchor) } ?? NSScreen.main!
        let frame = screen.visibleFrame
        let width = min(390, frame.width - 24)
        let height = min(max(size.height, 78), min(430, frame.height - 24))
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
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "character.bubble.fill").foregroundStyle(.mint)
                Text("日本語").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                Spacer()
                if loading { ProgressView().controlSize(.mini) }
            }
            ScrollView {
                Text(text).font(.system(size: 14)).lineSpacing(5)
                    .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
            }.frame(maxHeight: 345)
        }
        .padding(16).frame(width: 358)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.primary.opacity(0.10)))
    }
}
