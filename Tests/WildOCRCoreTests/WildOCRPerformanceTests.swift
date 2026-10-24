import XCTest
@testable import WildOCRCore

final class WildOCRPerformanceTests: XCTestCase {
    func testSummary() {
        let times = [100, 120, 300, 500].map {
            WildOCRPerformanceSample(engine: "vision", configuration: "fast",
                                     decodeMs: 20, recognizeMs: $0 - 20,
                                     totalMs: $0, lines: 5)
        }
        let summary = WildOCRPerformanceSummary(times)!
        XCTAssertEqual(summary.count, 4)
        XCTAssertEqual(summary.p50, 120)
        XCTAssertEqual(summary.p95, 500)
        XCTAssertEqual(summary.max, 500)
        XCTAssertEqual(summary.averageDecode, 20)
        XCTAssertEqual(summary.averageRecognition, 235)
    }
    func testEmptySummary() {
        XCTAssertNil(WildOCRPerformanceSummary([]))
    }
}
