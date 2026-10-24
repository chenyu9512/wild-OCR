import XCTest
@testable import WildOCRCore

final class WildOCRExpansionTests: XCTestCase {
    func testModelManifestTraversalIsRejected() {
        let good = WildOCRModelPack.Asset(path: "models/rec.onnx",
            sha256: String(repeating: "a", count: 64), size: 1024)
        let bad = WildOCRModelPack.Asset(path: "../rec.onnx",
            sha256: good.sha256, size: 1024)
        XCTAssertTrue(good.isValid)
        XCTAssertFalse(bad.isValid)
        let pack = WildOCRModelPack(schemaVersion: 1, id: "test-model",
            displayName: "Test", engine: "paddle-onnx", license: "test",
            scripts: [.han], languages: ["zh"], assets: [good])
        XCTAssertNil(pack.validationIssue)
    }
    func testCERAndImageEquality() {
        XCTAssertEqual(OCRComparison.characterErrorRate(
            reference: "hello", hypothesis: "helo")!, 0.2, accuracy: 0.0001)
        XCTAssertNil(OCRComparison.characterErrorRate(reference: "", hypothesis: "x"))
        let hash = String(repeating: "a", count: 64)
        let a = OCRBenchmarkResult(imageSHA256: hash, engineID: "apple-vision",
            quality: "fast", durationMs: 100, text: "abc")
        let b = OCRBenchmarkResult(imageSHA256: hash, engineID: "paddle-ocr-external",
            quality: "accurate", durationMs: 200, text: "def")
        XCTAssertTrue(OCRComparison.matches(a, b))
    }
}
