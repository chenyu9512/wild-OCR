import Foundation
import WildOCRCore

/// Adapter boundary for a future ONNX Runtime / Core ML / ncnn PaddleOCR
/// detector + recognizer pipeline. This package deliberately does not claim
/// to ship a model or functioning native PaddleOCR runtime yet.
public protocol PaddleOCRRuntime {
    /// Inspect an installed manifest and verify model checksum before loading.
    /// The implementation owns the platform image representation and inference.
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
