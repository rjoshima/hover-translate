import SwiftUI
import AppKit

@main struct HoverTranslateApp {
    @MainActor static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor final class TranslationStatusItem: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let model: AppModel
    private let openSettings: () -> Void

    init(model: AppModel, openSettings: @escaping () -> Void) {
        self.model = model
        self.openSettings = openSettings
        super.init()
        if let button = item.button {
            button.title = "訳"
            button.font = .systemFont(ofSize: 14, weight: .semibold)
            button.toolTip = "選択した文章を日本語に翻訳（右クリックで設定）"
            button.setAccessibilityLabel("選択した文章を日本語に翻訳")
            button.target = self
            button.action = #selector(clicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }
    @objc private func clicked() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            let menu = NSMenu()
            let settings = NSMenuItem(title: "設定を開く", action: #selector(settings), keyEquivalent: "")
            settings.target = self; menu.addItem(settings)
            let clear = NSMenuItem(title: "翻訳を閉じてキャッシュを消す", action: #selector(clear), keyEquivalent: "")
            clear.target = self; menu.addItem(clear)
            menu.addItem(.separator())
            let quit = NSMenuItem(title: "終了", action: #selector(quit), keyEquivalent: "")
            quit.target = self; menu.addItem(quit)
            item.menu = menu
            item.button?.performClick(nil)
            item.menu = nil
        } else if !model.hasKey {
            openSettings()
        } else {
            model.translateSelection(at: NSEvent.mouseLocation)
        }
    }
    @objc private func settings() { openSettings() }
    @objc private func clear() { model.stop() }
    @objc private func quit() { NSApp.terminate(nil) }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    private let model = AppModel()
    private var statusItem: TranslationStatusItem?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let mainMenu = NSMenu()
        let appItem = NSMenuItem()
        let appMenu = NSMenu(title: "Hover Translate")
        let settings = NSMenuItem(title: "設定を開く", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self; appMenu.addItem(settings)
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "終了", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu; mainMenu.addItem(appItem)
        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "編集")
        for (title, action, key) in [("切り取り", "cut:", "x"), ("コピー", "copy:", "c"),
                                     ("ペースト", "paste:", "v"), ("すべて選択", "selectAll:", "a")] {
            editMenu.addItem(withTitle: title, action: Selector(action), keyEquivalent: key)
        }
        editItem.submenu = editMenu; mainMenu.addItem(editItem)
        NSApp.mainMenu = mainMenu
        statusItem = TranslationStatusItem(model: model) { [weak self] in self?.showSettings() }
        showSettings()
    }
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        showSettings(); return true
    }
    @objc func showSettings() {
        if settingsWindow == nil {
            let view = NSHostingView(rootView: ScrollView { SettingsView(model: model) })
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 576, height: 720),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable],
                                  backing: .buffered, defer: false)
            window.title = "Hover Translate"
            window.identifier = NSUserInterfaceItemIdentifier("settings")
            window.isReleasedWhenClosed = false
            window.minSize = NSSize(width: 560, height: 480)
            window.contentView = view
            window.center()
            settingsWindow = window
        }
        guard let window = settingsWindow else { return }
        window.collectionBehavior.insert(.moveToActiveSpace)
        window.deminiaturize(nil)
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var key = ""
    @State private var editingKey = false
    @State private var showApps = false
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 14) {
                Image(systemName: "character.bubble.fill").font(.system(size: 36)).foregroundStyle(.mint)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hover Translate").font(.title.bold())
                    Text("選択して「訳」。必要なときだけ日本語に。").foregroundStyle(.secondary)
                }
            }
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Text("1  OpenRouterにつなぐ").font(.headline)
                    if !model.hasKey || editingKey {
                        HStack {
                            SecureField("OpenRouter APIキー", text: $key)
                                .textFieldStyle(.roundedBorder)
                                .accessibilityLabel("OpenRouter APIキー")
                            Button("保存") {
                                if model.saveKey(key) { key = ""; editingKey = false }
                            }.disabled(key.isEmpty)
                            if model.hasKey {
                                Button("キャンセル") { key = ""; editingKey = false }
                            }
                        }
                    } else {
                        HStack {
                            Label("キーは保存済みです。再入力は不要です。", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.teal)
                            Spacer()
                            Button("変更") { editingKey = true }
                        }
                    }
                    HStack {
                        Button(model.demoBusy ? "接続中…" : "接続テスト") { model.demo() }
                            .disabled(!model.hasKey || model.demoBusy)
                        if model.hasKey { Button("キーを削除", role: .destructive) { model.deleteKey() } }
                    }
                    Text("キーはこのMacに保存します。iCloud同期はまだ未対応です。GitHubには入りません。")
                        .font(.caption).foregroundStyle(.secondary)
                    if !model.translated.isEmpty {
                        Text(model.translated).textSelection(.enabled).font(.callout)
                            .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                            .background(.mint.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
                    }
                }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
            }
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Text("2  英文を読み取れるようにする").font(.headline)
                    Text("アクセシビリティ設定で「Hover Translate」を許可します。画面録画やクリップボードの読み取りは使いません。")
                        .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                    Button("Macのアクセス設定を開く") { model.openPermissions() }
                    Divider()
                    HStack {
                        Text("対象：\(targetNames)").font(.callout)
                        Spacer()
                        Button("変更") { showApps.toggle() }.popover(isPresented: $showApps) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("翻訳するアプリ").font(.headline)
                                ForEach(runningApps, id: \.bundleIdentifier) { app in
                                    if let id = app.bundleIdentifier {
                                        Toggle(id == "com.openai.codex" ? "Codex" : app.localizedName ?? id, isOn: Binding(
                                            get: { model.targets.contains(id) },
                                            set: { _ in model.toggleTarget(id) }
                                        ))
                                    }
                                }
                            }.padding(20).frame(width: 260)
                        }
                    }
                }.padding(8).frame(maxWidth: .infinity, alignment: .leading)
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("3  英文を選択して、メニューバーの「訳」を押す").font(.headline)
                Text("コピーは不要です。ボタンを押したときだけ翻訳します。設定・終了は「訳」を右クリックしてください。")
                    .font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
                Text(model.status).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            Text("GPT-4.1 nano · 本日あと\(model.remaining)回\n「訳」を押したときの選択文だけがOpenRouterと翻訳モデルの提供元に送られます。自動送信・コピー監視・原文や訳の履歴保存はしません。")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.padding(28).frame(width: 520)
    }
    private var runningApps: [NSRunningApplication] {
        NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular && $0.bundleIdentifier != Bundle.main.bundleIdentifier }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }
    private var targetNames: String {
        model.targets.map { id in
            (id == "com.openai.codex" ? "Codex" : id == "com.anthropic.claudefordesktop" ? "Claude" : NSRunningApplication.runningApplications(withBundleIdentifier: id).first?.localizedName ?? id)
        }.joined(separator: "、")
    }
}
