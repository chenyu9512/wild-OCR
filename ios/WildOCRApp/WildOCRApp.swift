import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import CryptoKit
import UIKit
import Vision
import ImageIO

/// Presets use Vision's normalized lower-left origin.
enum WildOCRScanArea: String, CaseIterable, Identifiable {
    case full, dialogue, bottom, custom
    var id: String { rawValue }
    var title: String {
        switch self {
        case .full: return "整张画面"
        case .dialogue: return "中间正文"
        case .bottom: return "底部字幕"
        case .custom: return "自定义区域"
        }
    }
    var region: OCRRegion {
        switch self {
        case .full: return .full
        case .dialogue: return OCRRegion(x: 0.04, y: 0.22, width: 0.92, height: 0.56)
        case .bottom: return OCRRegion(x: 0.03, y: 0.02, width: 0.94, height: 0.31)
        case .custom: return .full
        }
    }
}

struct WildOCRSessionEntry: Identifiable {
    let id = UUID()
    let createdAt = Date()
    let text: String
    let blockCount: Int
    let durationMs: Int
    let quality: String
    let language: String
}

@main
struct WildOCRApp: App {
    var body: some Scene {
        WindowGroup { WildHomeView().preferredColorScheme(.dark) }
    }
}

@MainActor
final class WildAppState: ObservableObject {
    @Published var photo: UIImage?
    @Published var sourceData: Data?
    @Published var quality: OCRQuality = .fast
    @Published var engineID = "apple-vision"
    @Published var selectedLanguage = "auto"
    @Published var scanArea: WildOCRScanArea = .full
    @Published var customRegion = OCRRegion(x: 0.06, y: 0.10, width: 0.88, height: 0.80)
    var effectiveRegion: OCRRegion { scanArea == .custom ? customRegion : scanArea.region }
    @Published var showBoxes = true
    @Published private(set) var performanceSamples: [WildOCRPerformanceSample] = []
    var performanceSummary: WildOCRPerformanceSummary? {
        WildOCRPerformanceSummary(performanceSamples)
    }
    var performanceCSV: String {
        let header = "time,engine,configuration,decode_ms,recognize_ms,total_ms,lines,thermal"
        return ([header] + performanceSamples.map {
            "\($0.timestamp.timeIntervalSince1970),\($0.engine),\($0.configuration),\($0.decodeMs),\($0.recognizeMs),\($0.totalMs),\($0.lines),\($0.thermal)"
        }).joined(separator: "\n")
    }
    func clearPerformanceHistory() { performanceSamples.removeAll() }
    @Published var savedSessions: [WildOCRSessionEntry] = []
    @Published var text = ""
    @Published var rows: [OCRBlock] = []
    @Published var status = "从相册或文件导入图片"
    @Published var busy = false
    @Published var measuredMs = 0
    @Published var summary = "尚未测试"
    @Published var comparison: OCRBenchmarkResult?
    @Published var externalText = ""
    @Published var externalTime = ""
    @Published var groundTruth = ""
    @Published var packs: [WildOCRModelPack] = []
    @Published var modelStatus = "Paddle 模型文件可导入校验；App 内推理尚未链接"
    // Separate statistics per image, quality, language and scan region.
    // Mixing them would make a comparison display misleading P50/P95.
    private var metricsByConfiguration: [String: OCRMetrics] = [:]
    private(set) var last: OCRBenchmarkResult?

    var fingerprint: String? {
        guard let data = sourceData else { return nil }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    func load(_ data: Data) {
        guard let photo = UIImage(data: data), photo.cgImage != nil else {
            status = "图片格式不支持"; return
        }
        self.photo = photo
        sourceData = data
        text = ""
        rows = []
        comparison = nil
        last = nil
        metricsByConfiguration.removeAll()
        performanceSamples.removeAll()
        summary = "尚未测试"
        status = "已加载图片 · \(Int(photo.size.width)) × \(Int(photo.size.height))"
    }

    func recognize(repetitions: Int = 1) {
        guard !busy, let bytes = sourceData, let hash = fingerprint else { return }
        busy = true
        status = engineID == "paddle-onnx" ? "PaddleOCR 模型本机识别中…" : "Apple Vision 本机识别中…"
        let selectedQuality = quality
        let selectedEngine = engineID
        let selectedRegion = effectiveRegion
        let statisticKey = hash + "|" + selectedEngine + "|" + selectedQuality.rawValue + "|" +
            scanArea.rawValue + "|" + selectedLanguage
        let languageHints = selectedLanguage == "auto" ? [] : [selectedLanguage]
        Task {
            do {
                let results = try await Task.detached(priority: .userInitiated) {
                    () throws -> [(blocks: [OCRBlock], time: Int, decodeMs: Int, totalMs: Int)] in
                    let decodeStart = ProcessInfo.processInfo.systemUptime
                    guard let photo = UIImage(data: bytes), let image = photo.cgImage else {
                        throw NSError(domain: "wild.ocr", code: 1,
                                      userInfo: [NSLocalizedDescriptionKey: "图片解码失败"])
                    }
                    let orientation: CGImagePropertyOrientation
                    switch photo.imageOrientation {
                    case .up: orientation = .up
                    case .down: orientation = .down
                    case .left: orientation = .left
                    case .right: orientation = .right
                    case .upMirrored: orientation = .upMirrored
                    case .downMirrored: orientation = .downMirrored
                    case .leftMirrored: orientation = .leftMirrored
                    case .rightMirrored: orientation = .rightMirrored
                    @unknown default: orientation = .up
                    }
                    let decodeMs = max(0, Int(1000 *
                        (ProcessInfo.processInfo.systemUptime - decodeStart)))
                    var results: [(blocks: [OCRBlock], time: Int, decodeMs: Int, totalMs: Int)] = []
                    for _ in 0..<min(20, max(1, repetitions)) {
                        try Task.checkCancellation()
                        let start = ProcessInfo.processInfo.systemUptime
                        let blocks: [OCRBlock]
                        #if WILD_OCR_PADDLE
                        if selectedEngine == "paddle-onnx" {
                            blocks = try await WildPaddleRuntime.shared.recognize(
                                photo, region: selectedRegion).blocks
                        } else {
                            blocks = try AppleVisionOCR.recognize(image,
                                orientation: orientation, region: selectedRegion,
                                languageHints: languageHints, quality: selectedQuality)
                        }
                        #else
                        blocks = try AppleVisionOCR.recognize(image,
                            orientation: orientation, region: selectedRegion,
                            languageHints: languageHints, quality: selectedQuality)
                        #endif
                        let time = max(0, Int(1000 *
                            (ProcessInfo.processInfo.systemUptime - start)))
                        results.append((blocks: blocks, time: time,
                                        decodeMs: decodeMs,
                                        totalMs: time + decodeMs))
                    }
                    return results
                }.value
                var measurements = metricsByConfiguration[statisticKey] ?? OCRMetrics()
                for result in results { measurements.record(durationMs: result.time) }
                let thermal = ProcessInfo.processInfo.thermalState
                let thermalName: String
                switch thermal {
                case .nominal: thermalName = "nominal"
                case .fair: thermalName = "fair"
                case .serious: thermalName = "serious"
                case .critical: thermalName = "critical"
                @unknown default: thermalName = "unknown"
                }
                for result in results {
                    performanceSamples.append(WildOCRPerformanceSample(
                        engine: selectedEngine, configuration: selectedQuality.rawValue
                            + "-" + scanArea.rawValue + "-" + selectedLanguage,
                        decodeMs: result.decodeMs, recognizeMs: result.time,
                        totalMs: result.totalMs, lines: result.blocks.count,
                        thermal: thermalName))
                }
                if performanceSamples.count > 256 {
                    performanceSamples.removeFirst(performanceSamples.count - 256)
                }
                metricsByConfiguration[statisticKey] = measurements
                guard let value = results.last else { return }
                rows = value.blocks
                measuredMs = value.time
                text = rows.map(\.text).joined(separator: "\n")
                last = OCRBenchmarkResult(imageSHA256: hash,
                    engineID: selectedEngine, quality: selectedQuality.rawValue,
                    durationMs: value.time, text: text)
                summary = "\(selectedEngine) \(measurements.count) 次 · P50 \(measurements.p50 ?? 0)ms · P95 \(measurements.p95 ?? 0)ms"
                status = "完成 · \(rows.count) 行 · \(value.time)ms"
            } catch {
                status = "OCR 失败：" + error.localizedDescription
            }
            busy = false
        }
    }

    func saveCurrentResult() {
        guard !busy, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let entry = WildOCRSessionEntry(text: text, blockCount: rows.count,
                                        durationMs: measuredMs,
                                        quality: quality.rawValue, language: selectedLanguage)
        savedSessions.insert(entry, at: 0)
        if savedSessions.count > 40 { savedSessions.removeLast() }
        status = "已保存到本次会话记录（退出 App 后不保留）"
    }

    func removeSession(_ id: UUID) {
        savedSessions.removeAll { $0.id == id }
    }

    func clearSessions() {
        savedSessions.removeAll()
    }

    func clearCurrentResult() {
        rows = []
        text = ""
        comparison = nil
        last = nil
        groundTruth = ""
        externalText = ""
        externalTime = ""
        summary = "尚未测试"
        status = photo == nil ? "选择图片开始本机 OCR" : "已清除本次识别结果"
    }

    func applyManualPaddle() {
        guard let hash = fingerprint, let duration = Int(externalTime), duration >= 0 else {
            status = "请先选图，并输入真实的 PaddleOCR 耗时"; return
        }
        comparison = OCRBenchmarkResult(imageSHA256: hash,
            engineID: "paddle-ocr-manual", quality: "external",
            durationMs: duration, text: externalText)
        status = "Paddle 外部测试已记录（并非本 App 内推理）"
    }

    func importPaddleReport(_ data: Data) {
        guard let report = try? JSONDecoder().decode(OCRBenchmarkResult.self, from: data),
              report.engineID.hasPrefix("paddle-ocr"),
              let last, OCRComparison.matches(last, report) else {
            status = "对照失败：图片 SHA-256 不一致或 JSON 格式不正确"; return
        }
        comparison = report
        status = "已导入外部 PaddleOCR 测试记录"
    }

    func refreshModels() {
        let root = Self.modelDirectory()
        packs = (try? FileManager.default.contentsOfDirectory(
            at: root, includingPropertiesForKeys: nil))?.compactMap { folder in
                guard let data = try? Data(contentsOf:
                    folder.appendingPathComponent("manifest.json")),
                      let pack = try? JSONDecoder().decode(WildOCRModelPack.self, from: data),
                      pack.id == folder.lastPathComponent,
                      pack.validationIssue == nil else { return nil }
                return pack
            } ?? []
    }

    nonisolated static func modelDirectory() -> URL {
        let root = FileManager.default.urls(for: .applicationSupportDirectory,
                    in: .userDomainMask)[0].appendingPathComponent("wild-models",
                    isDirectory: true)
        try? FileManager.default.createDirectory(
            at: root, withIntermediateDirectories: true)
        return root
    }

    /// Security-scoped folder; verify all files before moving to permanent storage.
    func installFolder(_ source: URL) {
        busy = true
        modelStatus = "正在离线校验 SHA-256…"
        Task {
            let result = await Task.detached(priority: .utility) {
                Result { try Self.verifyAndInstall(source) }
            }.value
            busy = false
            switch result {
            case .success(let name): modelStatus = "已校验文件：\(name)（Paddle 推理待接入）"
            case .failure(let error): modelStatus = "安装失败：" + error.localizedDescription
            }
            refreshModels()
        }
    }

    nonisolated static func verifyAndInstall(_ source: URL) throws -> String {
        let access = source.startAccessingSecurityScopedResource()
        defer { if access { source.stopAccessingSecurityScopedResource() } }
        let fm = FileManager.default
        let data = try Data(contentsOf: source.appendingPathComponent("manifest.json"))
        let pack = try JSONDecoder().decode(WildOCRModelPack.self, from: data)
        if let issue = pack.validationIssue {
            throw NSError(domain: "wild.ocr", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: issue])
        }
        let folder = modelDirectory()
        let staging = folder.appendingPathComponent(".staging-" + UUID().uuidString)
        try fm.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: staging) }
        for asset in pack.assets {
            let original = source.appendingPathComponent(asset.path)
            // Check every component, not only the last file, for symlinks.
            var current = source
            for component in asset.path.split(separator: "/") {
                current.appendPathComponent(String(component))
                let v = try current.resourceValues(forKeys: [.isSymbolicLinkKey])
                guard v.isSymbolicLink != true else {
                    throw NSError(domain: "wild.ocr", code: 3,
                                  userInfo: [NSLocalizedDescriptionKey: "禁止符号链接"])
                }
            }
            let attrs = try original.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey])
            guard attrs.isRegularFile == true, Int64(attrs.fileSize ?? -1) == asset.size else {
                throw NSError(domain: "wild.ocr", code: 4,
                              userInfo: [NSLocalizedDescriptionKey: "模型大小不符"])
            }
            let handle = try FileHandle(forReadingFrom: original)
            defer { try? handle.close() }
            var sha = SHA256()
            while let data = try handle.read(upToCount: 1_048_576), !data.isEmpty {
                sha.update(data: data)
            }
            let digest = sha.finalize().map { String(format: "%02x", $0) }.joined()
            guard digest == asset.sha256 else {
                throw NSError(domain: "wild.ocr", code: 5,
                              userInfo: [NSLocalizedDescriptionKey: "模型哈希校验失败"])
            }
            let destination = staging.appendingPathComponent(asset.path)
            try fm.createDirectory(at: destination.deletingLastPathComponent(),
                                   withIntermediateDirectories: true)
            try fm.copyItem(at: original, to: destination)
        }
        try data.write(to: staging.appendingPathComponent("manifest.json"))
        let destination = folder.appendingPathComponent(pack.id)
        // Only replace an old verified pack after the new files are staged.
        let backup = folder.appendingPathComponent(".backup-" + UUID().uuidString)
        let existed = fm.fileExists(atPath: destination.path)
        if existed { try fm.moveItem(at: destination, to: backup) }
        do { try fm.moveItem(at: staging, to: destination) }
        catch {
            if existed { try? fm.moveItem(at: backup, to: destination) }
            throw error
        }
        if existed { try? fm.removeItem(at: backup) }
        return pack.displayName
    }

    func deleteModel(_ pack: WildOCRModelPack) {
        let id = pack.id
        guard !id.isEmpty, id.unicodeScalars.allSatisfy({
            CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789-_").contains($0)
        }) else { return }
        try? FileManager.default.removeItem(at: Self.modelDirectory()
            .appendingPathComponent(id))
        refreshModels()
    }

    var visionCER: Double? {
        guard let last else { return nil }
        return OCRComparison.characterErrorRate(
            reference: groundTruth, hypothesis: last.text)
    }
    var paddleCER: Double? {
        guard let comparison else { return nil }
        return OCRComparison.characterErrorRate(
            reference: groundTruth, hypothesis: comparison.text)
    }
}

