import Foundation

public enum TextPolicy {
    // These recognizable patterns reduce accidental disclosure; they are not a full DLP system.
    public static func containsCredential(_ text: String) -> Bool {
        let patterns = [
            #"(?i)\bsk-(?:or-v1-|proj-|ant-)?[A-Za-z0-9_-]{16,}"#,
            #"\b(?:gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[A-Z0-9]{16})"#,
            #"-----BEGIN (?:[A-Z0-9]+ )?PRIVATE KEY-----"#,
            #"(?i)\b(?:api[_-]?key|access[_-]?token|client[_-]?secret|password|passwd)\s*[=:]\s*[\"']?[^\s\"']{4,}"#,
            #"(?i)\bBearer\s+[A-Za-z0-9._~+/-]{12,}"#
        ]
        return patterns.contains { text.range(of: $0, options: .regularExpression) != nil }
    }

    /// Bound the unit of translation; never silently send or translate a whole document.
    public static func candidate(_ text: String) -> String? {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (3...1800).contains(value.count), !containsCredential(value) else { return nil }
        let letters = value.unicodeScalars.filter { CharacterSet.letters.contains($0) }
        let latin = letters.filter { (65...90).contains($0.value) || (97...122).contains($0.value) }
        guard latin.count >= 3, Double(latin.count) / Double(max(letters.count, 1)) > 0.6 else { return nil }
        return value
    }
}

public struct HoverGate {
    public var delay: TimeInterval
    private var x: Double = .infinity
    private var y: Double = .infinity
    private var changedAt: TimeInterval = 0
    private var fired = false

    public init(delay: TimeInterval = 0.7) { self.delay = delay }

    public mutating func reset() { x = .infinity; y = .infinity; fired = false }

    public mutating func ready(x: Double, y: Double, now: TimeInterval) -> Bool {
        if hypot(x - self.x, y - self.y) > 5 {
            self.x = x; self.y = y; changedAt = now; fired = false
            return false
        }
        guard !fired, now - changedAt >= delay else { return false }
        fired = true
        return true
    }
}

/// Session-only, bounded cache. Quitting the app discards all captured text.
public struct TranslationCache {
    private let limit: Int
    private var entries: [String: String] = [:]
    private var order: [String] = []
    public init(limit: Int = 64) { self.limit = max(1, limit) }
    public subscript(_ key: String) -> String? { entries[key] }
    public mutating func insert(_ value: String, for key: String) {
        if entries[key] == nil { order.append(key) }
        entries[key] = value
        while order.count > limit { entries.removeValue(forKey: order.removeFirst()) }
    }
    public mutating func clear() { entries.removeAll(); order.removeAll() }
}
