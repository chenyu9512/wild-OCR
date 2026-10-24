#if canImport(Vision) && canImport(CoreVideo)
import Foundation
import Vision
import CoreVideo
import ImageIO
#if !WILD_OCR_EMBEDDED
import WildOCRCore
#endif

/// On-device native OCR; run on a background worker.
public enum AppleVisionOCR {
    public static let engineID = "apple-vision"

    @available(iOS 16.0, macOS 13.0, *)
    public static func recognize(_ buffer: CVPixelBuffer,
                                 orientation: CGImagePropertyOrientation = .up,
                                 region: OCRRegion = .full,
                                 languageHints: [String] = [],
                                 quality: OCRQuality = .fast) throws -> [OCRBlock] {
        try run(VNImageRequestHandler(cvPixelBuffer: buffer,
                                    orientation: orientation, options: [:]),
                region: region, languageHints: languageHints, quality: quality)
    }

    @available(iOS 16.0, macOS 13.0, *)
    public static func recognize(_ image: CGImage,
                                 orientation: CGImagePropertyOrientation = .up,
                                 region: OCRRegion = .full,
                                 languageHints: [String] = [],
                                 quality: OCRQuality = .fast) throws -> [OCRBlock] {
        try run(VNImageRequestHandler(cgImage: image,
                                    orientation: orientation, options: [:]),
                region: region, languageHints: languageHints, quality: quality)
    }

    @available(iOS 16.0, macOS 13.0, *)
    private static func run(_ handler: VNImageRequestHandler,
                            region: OCRRegion, languageHints: [String],
                            quality: OCRQuality) throws -> [OCRBlock] {
        guard region.isValid else { throw OCREngineError.invalidRegion }
        let req = VNRecognizeTextRequest()
        req.recognitionLevel = quality == .fast ? .fast : .accurate
        req.automaticallyDetectsLanguage = languageHints.isEmpty
        req.usesLanguageCorrection = true
        req.regionOfInterest = CGRect(x: region.x, y: region.y,
                                      width: region.width, height: region.height)
        if !languageHints.isEmpty {
            let supported = try req.supportedRecognitionLanguages()
            let selected = languageHints.filter(supported.contains)
            if selected.isEmpty { req.automaticallyDetectsLanguage = true }
            else { req.recognitionLanguages = selected }
        }
        try handler.perform([req])
        let lines = (req.results ?? []).compactMap { ob -> (String, CGRect, Double)? in
            guard let candidate = ob.topCandidates(1).first else { return nil }
            return (candidate.string, ob.boundingBox, Double(candidate.confidence))
        }.sorted {
            abs($0.1.midY - $1.1.midY) < 0.02 ? $0.1.minX < $1.1.minX : $0.1.midY > $1.1.midY
        }
        return lines.enumerated().map { i, ob in
            OCRBlock(text: ob.0,
                     region: OCRRegion(x: Double(ob.1.minX), y: Double(ob.1.minY),
                         width: Double(ob.1.width), height: Double(ob.1.height)),
                     script: ScriptClassifier.classify(ob.0),
                     languageHint: ScriptClassifier.strongLanguageHint(ob.0),
                     confidence: ob.2, engineID: engineID, readingOrder: i)
        }
    }
}
#endif
