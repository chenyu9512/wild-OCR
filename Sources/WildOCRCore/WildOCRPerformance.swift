import Foundation

/// One run of on-device OCR. No screenshot pixels or recognized text are saved.
public struct WildOCRPerformanceSample: Codable, Sendable {
    public let engine: String
    public let configuration: String
    public let decodeMs: Int
    public let recognizeMs: Int
    public let totalMs: Int
    public let lines: Int
    public let thermal: String
    public let timestamp: Date

    public init(engine: String, configuration: String, decodeMs: Int,
                recognizeMs: Int, totalMs: Int, lines: Int,
                thermal: String = "unknown", timestamp: Date = Date()) {
        self.engine = engine
        self.configuration = configuration
        self.decodeMs = decodeMs
        self.recognizeMs = recognizeMs
        self.totalMs = totalMs
        self.lines = lines
        self.thermal = thermal
        self.timestamp = timestamp
    }
}

public struct WildOCRPerformanceSummary {
    public let count: Int
    public let p50: Int
    public let p95: Int
    public let max: Int
    public let mean: Int
    public let averageDecode: Int
    public let averageRecognition: Int

    public init?(_ items: [WildOCRPerformanceSample]) {
        guard !items.isEmpty else { return nil }
        let ordered = items.map(\.totalMs).sorted()
        let n = ordered.count
        func percentile(_ p: Double) -> Int {
            ordered[max(0, min(n - 1, Int(ceil(Double(n) * p)) - 1))]
        }
        count = n
        p50 = percentile(0.5)
        p95 = percentile(0.95)
        max = ordered[n - 1]
        mean = ordered.reduce(0, +) / n
        averageDecode = items.reduce(0) { $0 + $1.decodeMs } / n
        averageRecognition = items.reduce(0) { $0 + $1.recognizeMs } / n
    }
}
