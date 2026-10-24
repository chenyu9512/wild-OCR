import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import CryptoKit
import UIKit
import Vision
import ImageIO

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
    @Published var selectedLanguage = "auto"
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
    private var times = OCRMetrics()
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
        times = OCRMetrics()
        summary = "尚未测试"
        status = "已加载图片 · \(Int(photo.size.width)) × \(Int(photo.size.height))"
    }

    func recognize(repetitions: Int = 1) {
        guard !busy, let bytes = sourceData, let hash = fingerprint else { return }
        busy = true
        status = "Apple Vision 本机识别中…"
        let selectedQuality = quality
        let languageHints = selectedLanguage == "auto" ? [] : [selectedLanguage]
        Task {
            do {
                let results = try await Task.detached(priority: .userInitiated) {
                    () throws -> [(blocks: [OCRBlock], time: Int)] in
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
                    var results: [(blocks: [OCRBlock], time: Int)] = []
                    for _ in 0..<min(20, max(1, repetitions)) {
                        try Task.checkCancellation()
                        let start = ProcessInfo.processInfo.systemUptime
                        let blocks = try AppleVisionOCR.recognize(image,
                            orientation: orientation, languageHints: languageHints,
                            quality: selectedQuality)
                        let time = max(0, Int(1000 *
                            (ProcessInfo.processInfo.systemUptime - start)))
                        results.append((blocks: blocks, time: time))
                    }
                    return results
                }.value
                for result in results { times.record(durationMs: result.time) }
                guard let value = results.last else { return }
                rows = value.blocks
                measuredMs = value.time
                text = rows.map(\.text).joined(separator: "\n")
                last = OCRBenchmarkResult(imageSHA256: hash,
                    engineID: "apple-vision", quality: selectedQuality.rawValue,
                    durationMs: value.time, text: text)
                summary = "Vision \(times.count) 次 · P50 \(times.p50 ?? 0)ms · P95 \(times.p95 ?? 0)ms"
                status = "完成 · \(rows.count) 行 · \(value.time)ms"
            } catch {
                status = "OCR 失败：" + error.localizedDescription
            }
            busy = false
        }
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

struct WildHomeView: View {
    @StateObject private var vm = WildAppState()
    @State private var photoPicker: PhotosPickerItem?
    @State private var selectImageFile = false
    @State private var selectModelFolder = false
    @State private var selectComparisonFile = false

    var body: some View {
        TabView {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("wild-OCR").font(.largeTitle.bold()).foregroundStyle(.mint)
                        Text("Universal OCR · iPhone 本机多语言识别")
                            .foregroundStyle(.secondary)
                        PhotosPicker(selection: $photoPicker, matching: .images) {
                            Label("从相册选择图片", systemImage: "photo.on.rectangle")
                        }.buttonStyle(.borderedProminent)
                        Button("从文件导入图片") { selectImageFile = true }
                        if let image = vm.photo {
                            Image(uiImage: image).resizable().scaledToFit()
                                .frame(maxHeight: 250)
                        }
                        Picker("OCR 模式", selection: $vm.quality) {
                            Text("快速").tag(OCRQuality.fast)
                            Text("高精度").tag(OCRQuality.accurate)
                        }.pickerStyle(.segmented)
                        Picker("语言", selection: $vm.selectedLanguage) {
                            Text("自动识别").tag("auto")
                            Text("中文").tag("zh-Hans")
                            Text("日本語").tag("ja-JP")
                            Text("English").tag("en-US")
                            Text("한국어").tag("ko-KR")
                            Text("Русский").tag("ru-RU")
                            Text("Français").tag("fr-FR")
                        }
                        Button(vm.busy ? "识别中…" : "执行本机 OCR") { vm.recognize() }
                            .buttonStyle(.borderedProminent)
                            .disabled(vm.busy || vm.photo == nil)
                        Text(vm.status).font(.caption).foregroundStyle(.mint)
                        Text(vm.summary).font(.caption.monospacedDigit())
                        if !vm.text.isEmpty {
                            HStack {
                                Text("识别结果").font(.headline)
                                Spacer()
                                Button("复制") { UIPasteboard.general.string = vm.text }
                            }
                            Text(vm.text).textSelection(.enabled)
                            ForEach(vm.rows.indices, id: \.self) { i in
                                Text("\(i+1). \(vm.rows[i].script.rawValue) · \(vm.rows[i].text)")
                                    .font(.caption)
                            }
                        }
                    }.padding()
                }.navigationTitle("文字识别")
            }.tabItem { Label("识别", systemImage: "text.viewfinder") }
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("本机离线模型").font(.title2.bold())
                        Text("导入含 manifest.json 的文件夹，校验全部 SHA-256。已安装不代表已链接 Paddle 推理。")
                            .font(.caption).foregroundStyle(.secondary)
                        Button("导入本地模型文件夹") { selectModelFolder = true }
                            .buttonStyle(.borderedProminent)
                        Text(vm.modelStatus).font(.caption).foregroundStyle(.mint)
                        ForEach(WildOCRModelCatalog.titles, id: \.self) { name in
                            Text(name).frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12).background(.white.opacity(0.06),
                                                   in: RoundedRectangle(cornerRadius: 12))
                        }
                        Text("已校验模型包：\(vm.packs.count)")
                        ForEach(vm.packs, id: \.id) { pack in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(pack.displayName)
                                    Text(pack.id).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("删除", role: .destructive) { vm.deleteModel(pack) }
                            }.padding(10)
                        }
                    }.padding()
                }.navigationTitle("模型管理")
            }.tabItem { Label("模型", systemImage: "square.stack") }
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Vision / PaddleOCR A/B").font(.title2.bold())
                        Text("Vision 在本 App 中真实执行；PaddleOCR 结果需从独立的官方 iOS Demo 输入，不会伪装成同进程推理。")
                            .font(.caption).foregroundStyle(.secondary)
                        Button("Vision 重复执行 5 次") { vm.recognize(repetitions: 5) }
                            .buttonStyle(.borderedProminent)
                            .disabled(vm.busy || vm.photo == nil)
                        Text(vm.summary)
                        TextField("外部 PaddleOCR 耗时（ms）", text: $vm.externalTime)
                            .keyboardType(.numberPad).textFieldStyle(.roundedBorder)
                        TextEditor(text: $vm.externalText).frame(height: 95)
                        Button("记录外部 PaddleOCR 测试") { vm.applyManualPaddle() }
                        Button("导入外部 PaddleOCR JSON") { selectComparisonFile = true }
                        if let result = vm.comparison {
                            Text("Vision \(vm.measuredMs)ms · Paddle \(result.durationMs)ms")
                        }
                        Text("正确文字（用于 CER）").font(.headline)
                        TextField("输入经人工核对的正确原文", text: $vm.groundTruth,
                                  axis: .vertical).lineLimit(3...8)
                            .textFieldStyle(.roundedBorder)
                        if let cer = vm.visionCER {
                            Text(String(format: "Vision CER %.1f%%", cer * 100))
                        }
                        if let cer = vm.paddleCER {
                            Text(String(format: "PaddleOCR CER %.1f%%", cer * 100))
                        }
                    }.padding()
                }.navigationTitle("对照测试")
            }.tabItem { Label("对照", systemImage: "chart.bar.xaxis") }
        }
        .tint(.mint)
        .fileImporter(isPresented: $selectImageFile, allowedContentTypes: [.image]) {
            acceptFile($0, category: 1)
        }
        .fileImporter(isPresented: $selectComparisonFile, allowedContentTypes: [.json]) {
            acceptFile($0, category: 2)
        }
        .fileImporter(isPresented: $selectModelFolder, allowedContentTypes: [.folder]) {
            switch $0 {
            case .success(let url): vm.installFolder(url)
            case .failure(let e): vm.modelStatus = e.localizedDescription
            }
        }
        .onChange(of: photoPicker) { _, item in
            guard let item else { return }
            Task {
                do {
                    if let bytes = try await item.loadTransferable(type: Data.self) {
                        vm.load(bytes)
                    }
                } catch { vm.status = error.localizedDescription }
            }
        }
        .onAppear { vm.refreshModels() }
    }

    private func acceptFile(_ result: Result<URL, Error>, category: Int) {
        do {
            let url = try result.get()
            let granted = url.startAccessingSecurityScopedResource()
            defer { if granted { url.stopAccessingSecurityScopedResource() } }
            let data = try Data(contentsOf: url)
            if category == 1 { vm.load(data) }
            else { vm.importPaddleReport(data) }
        } catch { vm.status = "导入失败：" + error.localizedDescription }
    }
}
