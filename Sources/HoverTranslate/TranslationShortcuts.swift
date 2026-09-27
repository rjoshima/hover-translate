import AppKit
import Carbon
import Combine

/// Register only while a chosen source app is frontmost. No event tap or text polling.
@MainActor final class TranslationShortcuts {
    private let model: AppModel
    private var handler: EventHandlerRef?
    private var keys: [EventHotKeyRef] = []
    private var observation: NSObjectProtocol?
    private var targetSubscription: AnyCancellable?
    private static let signature: OSType = 0x4854524E // HTRN

    init(model: AppModel) {
        self.model = model
        var kind = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        let result = InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID()
            guard GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil,
                                    MemoryLayout<EventHotKeyID>.size, nil, &id) == noErr else { return OSStatus(eventNotHandledErr) }
            return MainActor.assumeIsolated {
                let owner = Unmanaged<TranslationShortcuts>.fromOpaque(context).takeUnretainedValue()
                guard id.signature == TranslationShortcuts.signature, id.id == 1 else { return OSStatus(eventNotHandledErr) }
                owner.model.translateSelection(at: NSEvent.mouseLocation, using: .apple)
                return noErr
            }
        }, 1, &kind, Unmanaged.passUnretained(self).toOpaque(), &handler)
        guard result == noErr else { model.shortcutStatus = "ショートカットを登録できませんでした（\(result)）。"; return }
        observation = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didActivateApplicationNotification,
                                                                        object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.updateRegistration() }
        }
        targetSubscription = model.$targets.sink { [weak self] _ in
            DispatchQueue.main.async { self?.updateRegistration() }
        }
        updateRegistration()
    }
    private func updateRegistration() {
        for key in keys { UnregisterEventHotKey(key) }
        keys.removeAll()
        guard let bundle = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
              model.targets.contains(bundle) else { return }
        var failed = false
        for (index, code) in [kVK_ANSI_T].enumerated() {
            var ref: EventHotKeyRef?
            let id = EventHotKeyID(signature: Self.signature, id: UInt32(index + 1))
            let result = RegisterEventHotKey(UInt32(code), UInt32(optionKey), id, GetApplicationEventTarget(), 0, &ref)
            if result == noErr, let ref { keys.append(ref) } else { failed = true }
        }
        model.shortcutStatus = failed
            ? "一部のショートカットを登録できませんでした。他のアプリのキー設定と競合している可能性があります。"
            : "⌥T：Apple翻訳"
    }
}
