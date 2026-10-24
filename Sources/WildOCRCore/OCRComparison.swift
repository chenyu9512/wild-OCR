import Foundation
public struct OCRBenchmarkResult: Codable, Sendable {
    public let imageSHA256: String
    public let engineID: String
    public let modelID: String?
    public let quality: String
    public let durationMs: Int
    public let text: String

    public init(imageSHA256: String, engineID: String,
                modelID: String? = nil, quality: String,
                durationMs: Int, text: String) {
        self.imageSHA256 = imageSHA256
        self.engineID = engineID
        self.modelID = modelID
        self.quality = quality
        self.durationMs = durationMs
        self.text = text
    }
}
public enum OCRComparison {
    public static func matches(_ lhs: OCRBenchmarkResult, _ rhs: OCRBenchmarkResult) -> Bool {
        lhs.imageSHA256.count == 64 && lhs.imageSHA256 == rhs.imageSHA256
    }
    public static func characterErrorRate(reference: String, hypothesis: String) -> Double? {
        let a = Array(reference.precomposedStringWithCanonicalMapping)
        let b = Array(hypothesis.precomposedStringWithCanonicalMapping)
        guard !a.isEmpty else { return nil }
        var old = Array(0...b.count)
        for (i, l) in a.enumerated() {
            var next = Array(repeating: 0, count: b.count + 1)
            next[0] = i + 1
            for (j, r) in b.enumerated() {
                next[j + 1] = min(old[j + 1] + 1,
                                  next[j] + 1,
                                  old[j] + (l == r ? 0 : 1))
            }
            old = next
        }
        return Double(old[b.count]) / Double(a.count)
    }
}
