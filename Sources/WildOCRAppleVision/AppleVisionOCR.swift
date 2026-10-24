#if canImport(Vision) && canImport(CoreVideo)
import Foundation
import Vision
import CoreVideo
import ImageIO
import WildOCRCore

/// Real iPhone OCR implementation. Keep it on an OCR worker queue.
/// A model cannot recognize characters it has no Vision language support for;
/// actual availability is queried from the active iOS revision.
public enum AppleVisionOCR {
    public static let engineID = "apple-vision"

    @available(iOS 16.0, macOS 13.0, *)
    public static func recognize(_ pixelBuffer: CVPixelBuffer,
                                 orientation: CGImagePropertyOrientation = .up,
                                 region: OCRRegion = .full,
                                 languageHints: [String] = [],
                                 quality: OCRQuality = .fast) throws -> [OCRBlock] {
        guard region.isValid else { throw OCREngineError.invalidRegion }
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = quality == .fast ? .fast : .accurate
        request.usesLanguageCorrection = true
        request.automaticallyDetectsLanguage = languageHints.isEmpty
        request.regionOfInterest = CGRect(x: region.x, y: region.y,
                                          width: region.width, height: region.height)
        if !languageHints.isEmpty {
            let supported = try request.supportedRecognitionLanguages()
            let available = languageHints.filter(supported.contains)
            if !available.isEmpty { request.recognitionLanguages = available }
            else { request.automaticallyDetectsLanguage = true }
        }
        try VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                  orientation: orientation, options: [:]).perform([request])
        let observed = (request.results ?? []).compactMap { item -> (text: String, rect: CGRect, confidence: Double)? in
            guard let best = item.topCandidates(1).first else { return nil }
            let text = best.string.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return nil }
            return (text, item.boundingBox, Double(best.confidence))
        }.sorted {
            abs($0.rect.midY - $1.rect.midY) < 0.02
                ? $0.rect.minX < $1.rect.minX : $0.rect.midY > $1.rect.midY
        }
        return observed.enumerated().map { index, line in
            let script = ScriptClassifier.classify(line.text)
            return OCRBlock(text: line.text,
                            region: OCRRegion(x: Double(line.rect.minX),
                                              y: Double(line.rect.minY),
                                              width: Double(line.rect.width),
                                              height: Double(line.rect.height)),
                            script: script,
                            languageHint: ScriptClassifier.strongLanguageHint(line.text),
                            confidence: line.confidence,
                            engineID: engineID, readingOrder: index)
        }
    }
}
#endif
