import Foundation

public struct OCRModelDescriptor: Codable, Sendable {
    public let id: String
    public let engineID: String
    public let scripts: Set<OCRScript>
    public let languages: Set<String>
    public let isInstalled: Bool
    public let acceptsAutomaticRouting: Bool

    public init(id: String, engineID: String, scripts: Set<OCRScript>,
                languages: Set<String>, isInstalled: Bool,
                acceptsAutomaticRouting: Bool = true) {
        self.id = id
        self.engineID = engineID
        self.scripts = scripts
        self.languages = languages
        self.isInstalled = isInstalled
        self.acceptsAutomaticRouting = acceptsAutomaticRouting
    }
}

public struct OCRRoute: Sendable {
    public let primaryEngine: String
    public let primaryModel: String?
    public let fallbackEngine: String?
}

/// Never routes to a model that has not actually been installed. The exact
/// supported scripts are supplied by inspected model manifests, not inferred
/// from a brand name or marketing claims.
public struct OCREngineRouter {
    public let fallbackEngineID: String
    public let models: [OCRModelDescriptor]

    public init(fallbackEngineID: String = "apple-vision", models: [OCRModelDescriptor]) {
        self.fallbackEngineID = fallbackEngineID
        self.models = models
    }

    public func route(script: OCRScript, preferredLanguage: String? = nil,
                      preferExternal: Bool = false) -> OCRRoute {
        guard preferExternal else {
            return OCRRoute(primaryEngine: fallbackEngineID,
                            primaryModel: nil, fallbackEngine: nil)
        }
        let available = models.filter { item in
            item.isInstalled && item.acceptsAutomaticRouting
            && (item.scripts.contains(script) || item.scripts.contains(.mixed))
            && (preferredLanguage == nil || item.languages.isEmpty
                || item.languages.contains(preferredLanguage!))
        }
        guard let model = available.first else {
            return OCRRoute(primaryEngine: fallbackEngineID,
                            primaryModel: nil, fallbackEngine: nil)
        }
        return OCRRoute(primaryEngine: model.engineID,
                        primaryModel: model.id,
                        fallbackEngine: fallbackEngineID)
    }
}
