import Foundation

/// Normalized bounding box, lower-left origin (Vision convention).
public struct OCRRegion: Codable, Hashable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public static let full = OCRRegion(x: 0, y: 0, width: 1, height: 1)

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public var isValid: Bool {
        [x, y, width, height].allSatisfy(\.isFinite)
        && x >= 0 && y >= 0 && width > 0 && height > 0
        && x + width <= 1.000001 && y + height <= 1.000001
    }
}

public enum OCRScript: String, Codable, CaseIterable, Sendable {
    case han, kana, hangul, latin, cyrillic, arabic, devanagari, thai
    case greek, hebrew, unknown, mixed
}

public enum OCRQuality: String, Codable, Sendable {
    case fast, accurate
}

public struct OCRBlock: Codable, Sendable {
    public let text: String
    public let region: OCRRegion
    public let script: OCRScript
    /// Best-effort source hint, not a guaranteed identification.
    public let languageHint: String?
    /// Nil if an OCR engine does not provide calibrated or comparable confidence.
    public let confidence: Double?
    public let engineID: String
    public let readingOrder: Int

    public init(text: String, region: OCRRegion, script: OCRScript,
                languageHint: String?, confidence: Double?, engineID: String,
                readingOrder: Int) {
        self.text = text
        self.region = region
        self.script = script
        self.languageHint = languageHint
        self.confidence = confidence
        self.engineID = engineID
        self.readingOrder = readingOrder
    }
}

public enum OCREngineError: Error, Equatable {
    case unsupportedPlatform
    case invalidRegion
    case modelNotInstalled(String)
    case noCompatibleModel(OCRScript)
}
