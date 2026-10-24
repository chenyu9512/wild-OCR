import Foundation

/// A local model manifest contains actual files and SHA-256 checksums.
public struct WildOCRModelPack: Codable, Sendable {
    public struct Asset: Codable, Sendable {
        public var path: String
        public var sha256: String
        public var size: Int64
        public var isValid: Bool {
            let parts = path.split(separator: "/", omittingEmptySubsequences: false)
            return !path.hasPrefix("/") && !path.contains("\\") && !path.contains(":")
                && parts.allSatisfy { !$0.isEmpty && $0 != "." && $0 != ".." }
                && sha256.count == 64 && sha256.utf8.allSatisfy {
                    (48...57).contains($0) || (97...102).contains($0)
                } && size > 0 && size <= 1_000_000_000
        }
    }
    public var schemaVersion: Int
    public var id: String
    public var displayName: String
    public var engine: String
    public var license: String
    public var scripts: [OCRScript]
    public var languages: [String]
    public var assets: [Asset]

    public var validationIssue: String? {
        guard schemaVersion == 1 else { return "Unsupported manifest revision" }
        let idCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-_")
        guard !id.isEmpty, id.count <= 80,
              id.unicodeScalars.allSatisfy({ idCharacters.contains($0) })
        else { return "Invalid model identifier" }
        guard !displayName.isEmpty, !license.isEmpty,
              !scripts.isEmpty, !languages.isEmpty,
              engine == "paddle-onnx" else { return "Missing or invalid model metadata" }
        guard !assets.isEmpty, assets.count <= 32, assets.allSatisfy(\.isValid),
              Set(assets.map(\.path)).count == assets.count,
              assets.reduce(Int64(0), { $0 + $1.size }) <= 1_500_000_000
        else { return "Invalid files or unsafe model paths" }
        return nil
    }
}
public enum WildOCRModelCatalog {
    public static let titles: [String] = [
        "PP-OCRv6 Small · 中英日和拉丁文字",
        "PP-OCRv5 Mobile · 中英日",
        "PP-OCRv5 Korean · 韩语",
        "PP-OCRv5 Latin · 拉丁多语言",
        "PP-OCRv5 East Slavic · 西里尔文字"
    ]
}
