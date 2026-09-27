import AppKit
import ApplicationServices
import HoverCore

@MainActor enum TextReader {
    /// Electron documents this opt-in for assistive clients. Without it a hit test
    /// may return only the browser container instead of the rendered text.
    static func prepare(pid: pid_t, bundleID: String) {
        guard ["com.openai.codex", "com.anthropic.claudefordesktop"].contains(bundleID) else { return }
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.25)
        _ = AXUIElementSetAttributeValue(app, "AXManualAccessibility" as CFString, kCFBooleanTrue)
    }
    static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }
    static func element(_ value: CFTypeRef?) -> AXUIElement? {
        guard let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }
    /// Read only the explicit selection belonging to the focused element.
    /// No cursor lookup, clipboard, sibling traversal, or whole-field fallback.
    static func selectedText(pid: pid_t) -> String? {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.25)
        guard var current = element(attribute(app, kAXFocusedUIElementAttribute)) else { return nil }
        var chain: [AXUIElement] = []
        for _ in 0..<6 {
            var owner: pid_t = 0
            guard AXUIElementGetPid(current, &owner) == .success, owner == pid else { return nil }
            if attribute(current, kAXSubroleAttribute) as? String == kAXSecureTextFieldSubrole { return nil }
            chain.append(current)
            guard let parent = element(attribute(current, kAXParentAttribute)) else { break }
            current = parent
        }
        for element in chain {
            if let selected = attribute(element, kAXSelectedTextAttribute) as? String, !selected.isEmpty {
                return selected
            }
        }
        return nil
    }
}
