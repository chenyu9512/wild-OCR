// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "wild-OCR",
    platforms: [.iOS(.v17), .macOS(.v13)],
    products: [
        .library(name: "WildOCRCore", targets: ["WildOCRCore"]),
        .library(name: "WildOCRAppleVision", targets: ["WildOCRAppleVision"]),
        .library(name: "WildOCRPaddleBridge", targets: ["WildOCRPaddleBridge"]),
    ],
    targets: [
        .target(name: "WildOCRCore"),
        .target(name: "WildOCRAppleVision", dependencies: ["WildOCRCore"]),
        .target(name: "WildOCRPaddleBridge", dependencies: ["WildOCRCore"]),
        .testTarget(name: "WildOCRCoreTests", dependencies: ["WildOCRCore"]),
    ]
)
