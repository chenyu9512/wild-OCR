import Foundation

/// Bounded, privacy-safe timings. No source text, screenshot, or API key.
public struct OCRMetrics {
    private var latencyMs: [Int] = []
    private let capacity: Int

    public init(capacity: Int = 256) { self.capacity = max(1, capacity) }

    public mutating func record(durationMs: Int) {
        guard durationMs >= 0, durationMs < 300_000 else { return }
        latencyMs.append(durationMs)
        if latencyMs.count > capacity { latencyMs.removeFirst(latencyMs.count - capacity) }
    }

    public var count: Int { latencyMs.count }
    public var p50: Int? { percentile(0.50) }
    public var p95: Int? { percentile(0.95) }

    private func percentile(_ p: Double) -> Int? {
        guard !latencyMs.isEmpty else { return nil }
        let ordered = latencyMs.sorted()
        let rank = Int(ceil(Double(ordered.count) * p))
        return ordered[max(0, min(rank - 1, ordered.count - 1))]
    }
}
