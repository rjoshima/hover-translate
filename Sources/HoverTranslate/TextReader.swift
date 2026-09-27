import AppKit
import ApplicationServices
import HoverCore

@MainActor enum TextReader {
    static func attribute(_ element: AXUIElement, _ name: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value
    }
    static func parameter(_ element: AXUIElement, _ name: String, _ value: CFTypeRef) -> CFTypeRef? {
        var output: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(element, name as CFString, value, &output) == .success else { return nil }
        return output
    }
    static func element(_ value: CFTypeRef?) -> AXUIElement? {
        guard let value, CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return (value as! AXUIElement)
    }
    static func rangeStart(_ raw: CFTypeRef) -> NSNumber? {
        guard CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
        let value = raw as! AXValue
        guard AXValueGetType(value) == .cfRange else { return nil }
        var range = CFRange()
        guard AXValueGetValue(value, .cfRange, &range), range.location >= 0 else { return nil }
        return NSNumber(value: range.location)
    }
    static func text(at point: CGPoint, pid: pid_t) -> String? {
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.15)
        var hit: AXUIElement?
        guard AXUIElementCopyElementAtPosition(app, Float(point.x), Float(point.y), &hit) == .success,
              var current = hit else { return nil }
        // A few nearby ancestors handle inline spans. Never traverse a document tree.
        for _ in 0..<4 {
            let role = attribute(current, kAXRoleAttribute) as? String ?? ""
            let subrole = attribute(current, kAXSubroleAttribute) as? String ?? ""
            if subrole == kAXSecureTextFieldSubrole { return nil }
            if let selected = attribute(current, kAXSelectedTextAttribute) as? String,
               let candidate = TextPolicy.candidate(selected) { return candidate }
            if [kAXTextAreaRole, kAXTextFieldRole].contains(role) {
                var p = point
                if let position = AXValueCreate(.cgPoint, &p),
                   let rawRange = parameter(current, kAXRangeForPositionParameterizedAttribute, position),
                   let index = rangeStart(rawRange),
                   let line = parameter(current, kAXLineForIndexParameterizedAttribute, index),
                   let range = parameter(current, kAXRangeForLineParameterizedAttribute, line),
                   let lineText = parameter(current, kAXStringForRangeParameterizedAttribute, range) as? String,
                   let candidate = TextPolicy.candidate(lineText) { return candidate }
            }
            if [kAXStaticTextRole, kAXTextFieldRole].contains(role),
               let value = attribute(current, kAXValueAttribute) as? String,
               let candidate = TextPolicy.candidate(value) { return candidate }
            guard let parent = element(attribute(current, kAXParentAttribute)) else { break }
            current = parent
        }
        return nil
    }
}
