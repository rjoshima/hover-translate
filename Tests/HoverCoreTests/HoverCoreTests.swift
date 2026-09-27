import XCTest
@testable import HoverCore

final class HoverCoreTests: XCTestCase {
    func testEnglishOnlyAndBounds() {
        XCTAssertEqual(TextPolicy.candidate("  Hello world.\n"), "Hello world.")
        XCTAssertNil(TextPolicy.candidate("日本語の文章です。"))
        XCTAssertNil(TextPolicy.candidate("12345"))
        XCTAssertNil(TextPolicy.candidate(String(repeating: "a", count: 1801)))
    }
    func testUnicodeResourceBoundBeforeTrimming() {
        for scalar in ["\u{0301}", "\u{200D}"] {
            let source = "abc" + String(repeating: scalar, count: 4000)
            XCTAssertLessThan(source.count, 1800)
            XCTAssertNil(TextPolicy.candidate(source))
        }
        XCTAssertNil(TextPolicy.candidate(String(repeating: " ", count: 7201) + "Hello"))
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
