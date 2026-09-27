import SwiftUI
import AppKit

@main struct HoverTranslateApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var model = AppModel()
    var body: some Scene {
        Window("Hover Translate", id: "settings") {
            SettingsView(model: model)
                .onAppear {
                    DispatchQueue.main.async { AppDelegate.showSettingsWindow() }
                }
        }.defaultSize(width: 560, height: 640).windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .appSettings) {
                OpenSettingsButton().keyboardShortcut(",", modifiers: .command)
            }
        }
        MenuBarExtra("Hover Translate", systemImage: "character.bubble") {
            Button(model.enabled ? "翻訳を停止" : "ホバー翻訳を開始") {
                if model.enabled { model.stop() } else { model.start() }
            }
            OpenSettingsButton()
            Divider()
            Text(model.status)
            Button("終了") { NSApplication.shared.terminate(nil) }.keyboardShortcut("q")
        }
    }
}

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        Self.showSettingsWindow()
        return true
    }

    static func showSettingsWindow() {
        guard let window = NSApp.windows.first(where: {
            $0.identifier?.rawValue == "settings" || $0.title == "Hover Translate"
        }) else { return }
        window.collectionBehavior.insert(.moveToActiveSpace)
        window.deminiaturize(nil)
        NSApp.unhide(nil)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }
}

struct OpenSettingsButton: View {
    @Environment(\.openWindow) private var openWindow
    var body: some View {
        Button("APIキーの設定を開く") {
            openWindow(id: "settings")
            DispatchQueue.main.async { AppDelegate.showSettingsWindow() }
        }
    }
}

struct SettingsView: View {
    @ObservedObject var model: AppModel
    @State private var key = ""
    @State private var showApps = false
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(spacing: 14) {
                Image(systemName: "character.bubble.fill").font(.system(size: 36)).foregroundStyle(.mint)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Hover Translate").font(.title.bold())
                    Text("英文の上でひと息。日本語がすぐそばに。").foregroundStyle(.secondary)
                }
            }
            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Text("1  OpenRouterにつなぐ").font(.headline)
                    HStack {
                        SecureField(model.hasKey ? "保存済み（変更する場合のみ入力）" : "OpenRouter APIキー", text: $key)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityLabel("OpenRouter APIキー")
                        Button("保存") { model.saveKey(key); key = "" }.disabled(key.isEmpty)
                    }
                    HStack {
                        Button(model.demoBusy ? "接続中…" : "接続テスト") { model.demo() }
                            .disabled(!model.hasKey || model.demoBusy)
                        if model.hasKey { Button("キーを削除", role: .destructive) { model.deleteKey() } }
                    }
                    Text("キーはこのMacのキーチェーンに保存します。GitHubには入りません。")
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
                Button(model.enabled ? "ホバー翻訳を停止" : "ホバー翻訳を開始") {
                    if model.enabled { model.stop() } else { model.start() }
                }.buttonStyle(.borderedProminent).tint(.teal).controlSize(.large).disabled(!model.hasKey)
                Text(model.status).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            }
            Divider()
            Text("GPT-4.1 nano · 本日あと\(model.remaining)回\n対象アプリでカーソルを止めた英文がOpenRouterと翻訳モデルの提供元に送られます。原文・訳の履歴は保存せず、終了するとキャッシュも消えます。")
                .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
        }.padding(28).frame(width: 520)
    }
    private var runningApps: [NSRunningApplication] {
        NSWorkspace.shared.runningApplications.filter { $0.activationPolicy == .regular && $0.bundleIdentifier != Bundle.main.bundleIdentifier }
            .sorted { ($0.localizedName ?? "") < ($1.localizedName ?? "") }
    }
    private var targetNames: String {
        model.targets.map { id in
            (id == "com.openai.codex" ? "Codex" : NSRunningApplication.runningApplications(withBundleIdentifier: id).first?.localizedName ?? id)
        }.joined(separator: "、")
    }
}
