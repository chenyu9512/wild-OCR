import XCTest
@testable import WildOCRCore

final class WildOCRCoreTests: XCTestCase {
    func testScriptCoverage() {
        XCTAssertEqual(ScriptClassifier.classify("こんにちは勇者"), .kana)
        XCTAssertEqual(ScriptClassifier.classify("안녕하세요"), .hangul)
        XCTAssertEqual(ScriptClassifier.classify("Привет"), .cyrillic)
        XCTAssertEqual(ScriptClassifier.classify("مرحبا"), .arabic)
        XCTAssertEqual(ScriptClassifier.classify("नमस्ते"), .devanagari)
        XCTAssertEqual(ScriptClassifier.classify("สวัสดี"), .thai)
        XCTAssertEqual(ScriptClassifier.classify("Γειά"), .greek)
        XCTAssertEqual(ScriptClassifier.classify("שלום"), .hebrew)
        XCTAssertEqual(ScriptClassifier.classify("Hello world"), .latin)
        XCTAssertEqual(ScriptClassifier.classify("生命"), .han)
        XCTAssertEqual(ScriptClassifier.classify("123 20%"), .unknown)
        XCTAssertEqual(ScriptClassifier.strongLanguageHint("漢字"), nil)
        XCTAssertEqual(ScriptClassifier.strongLanguageHint("まち"), "ja")
    }

    func testNoMissingModelsChosen() {
        let missing = OCRModelDescriptor(id: "paddle-latin", engineID: "paddle-ocr",
                                         scripts: [.latin], languages: [], isInstalled: false)
        let router = OCREngineRouter(models: [missing])
        let choice = router.route(script: .latin, preferExternal: true)
        XCTAssertEqual(choice.primaryEngine, "apple-vision")
        XCTAssertNil(choice.primaryModel)
        let installed = OCRModelDescriptor(id: "paddle-latin", engineID: "paddle-ocr",
                                           scripts: [.latin], languages: [], isInstalled: true)
        let choice2 = OCREngineRouter(models: [installed]).route(script: .latin,
                                                                preferExternal: true)
        XCTAssertEqual(choice2.primaryEngine, "paddle-ocr")
        XCTAssertEqual(choice2.fallbackEngine, "apple-vision")
    }

    func testChangeGate() {
        var g = OCRChangeGate()
        XCTAssertTrue(g.shouldScan(fingerprint: 1, uptime: 10, minimumInterval: 0.3))
        XCTAssertFalse(g.shouldScan(fingerprint: 1, uptime: 10.5, minimumInterval: 0.3))
        XCTAssertFalse(g.shouldScan(fingerprint: 2, uptime: 10.1, minimumInterval: 0.3))
        XCTAssertTrue(g.shouldScan(fingerprint: 2, uptime: 10.6, minimumInterval: 0.3))
        XCTAssertTrue(g.shouldScan(fingerprint: 2, uptime: 13.7, minimumInterval: 0.3))
    }

    func testPercentilesAndCapacity() {
        var m = OCRMetrics(capacity: 4)
        XCTAssertNil(m.p50)
        for ms in [100, 200, 300, 400, 500] { m.record(durationMs: ms) }
        XCTAssertEqual(m.count, 4)
        XCTAssertEqual(m.p50, 300)
        XCTAssertEqual(m.p95, 500)
    }
}
