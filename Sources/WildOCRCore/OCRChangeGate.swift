import Foundation

/// Given an upstream ROI fingerprint, helps the caller avoid redundant OCR.
/// Uses monotonic uptime (not wall-clock time) and never stores image bytes.
public struct OCRChangeGate {
    private var lastFingerprint: UInt64?
    private var lastScanUptime: TimeInterval = -.infinity

    public init() {}

    public mutating func shouldScan(fingerprint: UInt64,
                                    uptime: TimeInterval,
                                    minimumInterval: TimeInterval,
                                    unchangedRecheckInterval: TimeInterval = 3) -> Bool {
        guard uptime.isFinite, minimumInterval >= 0,
              unchangedRecheckInterval >= minimumInterval else { return false }
        guard uptime - lastScanUptime >= minimumInterval else { return false }
        if lastFingerprint == fingerprint
            && uptime - lastScanUptime < unchangedRecheckInterval { return false }
        lastFingerprint = fingerprint
        lastScanUptime = uptime
        return true
    }

    public mutating func reset() {
        lastFingerprint = nil
        lastScanUptime = -.infinity
    }
}
