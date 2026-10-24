import Foundation
#if !WILD_OCR_EMBEDDED
import WildOCRCore
#endif
/// This is a model bridge contract, not a pretend OCR inference implementation.
public protocol PaddleOCRRuntime {
    func installedModels() throws -> [OCRModelDescriptor]
}
public enum PaddleOCRBridgeStatus: String, Codable {
    case requiresRuntimeAndModels
    case runtimeLinked
    case modelReady
}
public enum PaddleOCRBridge {
    public static let engineID = "paddle-ocr"
    public static let initialStatus: PaddleOCRBridgeStatus = .requiresRuntimeAndModels
}
