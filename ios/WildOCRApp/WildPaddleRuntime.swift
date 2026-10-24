import Foundation
import CoreGraphics
import UIKit

#if WILD_OCR_PADDLE

/// Bridges the official PaddleOCR iOS detection + text recognition pipeline.
/// In experimental builds PaddleOCR's Engine sources and ONNX model assets are
/// vendored from a pinned upstream commit at build time.
actor WildPaddleRuntime {
    static let shared = WildPaddleRuntime()
    static var bundledModelPreset: String {
        guard let path = Bundle.main.path(forResource: "preset",
            ofType: "txt", inDirectory: "Models"),
              let text = try? String(contentsOfFile: path, encoding: .utf8) else {
            return "unknown"
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private let sessionManager = ORTSessionManager()
    private var loadedEngine: OCREngine?

    func recognize(_ source: UIImage, region: OCRRegion) async throws
        -> (blocks: [OCRBlock], detectionMs: Int, recognitionMs: Int) {
        guard region.isValid else { throw OCREngineError.invalidRegion }
        let upright = Self.makeUpright(source)
        guard let cg = upright.cgImage else {
            throw NSError(domain: "wild.paddle", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "无法生成图像"])
        }
        let rect = CGRect(x: CGFloat(region.x) * CGFloat(cg.width),
                          y: CGFloat(1 - region.y - region.height) * CGFloat(cg.height),
                          width: CGFloat(region.width) * CGFloat(cg.width),
                          height: CGFloat(region.height) * CGFloat(cg.height))
            .integral.intersection(CGRect(x: 0, y: 0, width: cg.width, height: cg.height))
        guard !rect.isEmpty, let crop = cg.cropping(to: rect) else {
            throw OCREngineError.invalidRegion
        }
        if loadedEngine == nil {
            try await sessionManager.loadModels(executionProvider: .cpu)
            loadedEngine = try OCREngine(sessionManager: sessionManager)
        }
        guard let loadedEngine else {
            throw NSError(domain: "wild.paddle", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "PaddleOCR 尚未初始化"])
        }
        let result = try await loadedEngine.run(crop)
        let width = max(Double(crop.width), 1)
        let height = max(Double(crop.height), 1)
        let blocks = result.results.enumerated().compactMap { index, item -> OCRBlock? in
            let points = item.polygon.compactMap { p -> (Double, Double)? in
                guard p.count >= 2 else { return nil }
                return (Double(p[0]), Double(p[1]))
            }
            guard !points.isEmpty else { return nil }
            let left = max(0, points.map(\.0).min() ?? 0)
            let top = max(0, points.map(\.1).min() ?? 0)
            let right = min(width, points.map(\.0).max() ?? width)
            let bottom = min(height, points.map(\.1).max() ?? height)
            guard right > left, bottom > top, !item.text.isEmpty else { return nil }
            let translated = OCRRegion(
                x: region.x + left / width * region.width,
                y: region.y + (1 - bottom / height) * region.height,
                width: (right - left) / width * region.width,
                height: (bottom - top) / height * region.height)
            return OCRBlock(text: item.text, region: translated,
                            script: ScriptClassifier.classify(item.text),
                            languageHint: ScriptClassifier.strongLanguageHint(item.text),
                            confidence: Double(item.confidence),
                            engineID: "paddle-onnx", readingOrder: index)
        }
        return (blocks: blocks,
                detectionMs: Int(result.detectionTime * 1000),
                recognitionMs: Int(result.recognitionTime * 1000))
    }

    /// Fixes captured photos whose underlying CGImage has a different
    /// orientation from the displayed UIImage.
    private static func makeUpright(_ source: UIImage) -> UIImage {
        guard source.imageOrientation != .up else { return source }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let size = CGSize(width: source.size.width, height: source.size.height)
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            source.draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
#endif
