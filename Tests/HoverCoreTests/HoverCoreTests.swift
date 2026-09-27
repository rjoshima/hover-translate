import XCTest
@testable import HoverCore

final class HoverCoreTests: XCTestCase {
    func testEnglishOnlyAndBounds() {
        XCTAssertEqual(TextPolicy.candidate("  Hello world.\n"), "Hello world.")
        XCTAssertNil(TextPolicy.candidate("日本語の文章です。"))
        XCTAssertNil(TextPolicy.candidate("12345"))
        XCTAssertNil(TextPolicy.candidate(String(repeating: "a", count: 1801)))
    }
    func testDwellIsOnceUntilMovement() {
        var gate = HoverGate()
        XCTAssertFalse(gate.ready(x: 10, y: 10, now: 0))
        XCTAssertFalse(gate.ready(x: 11, y: 10, now: 0.5))
        XCTAssertTrue(gate.ready(x: 10, y: 10, now: 0.8))
        XCTAssertFalse(gate.ready(x: 10, y: 10, now: 2))
        XCTAssertFalse(gate.ready(x: 50, y: 10, now: 3))
        XCTAssertTrue(gate.ready(x: 50, y: 10, now: 4))
        gate.reset()
        XCTAssertFalse(gate.ready(x: 50, y: 10, now: 5))
    }
    func testCacheEvictsAndClears() {
        var cache = TranslationCache(limit: 2)
        cache.insert("一", for: "one")
        cache.insert("二", for: "two")
        cache.insert("三", for: "three")
        XCTAssertNil(cache["one"])
        XCTAssertEqual(cache["two"], "二")
        cache.clear()
        XCTAssertNil(cache["two"])
    }
}
