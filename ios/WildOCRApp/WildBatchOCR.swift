import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import UIKit
import ImageIO

struct WildBatchItem: Identifiable {
    let id: UUID
    let name: String
    let bytes: Data
    var text = ""
    var blockCount = 0
    var elapsedMs = 0
    var status = "待识别"
    var failure: String?
    init(name: String, bytes: Data) {
        id = UUID()
        self.name = name
        self.bytes = bytes
    }
}

@MainActor
final class WildBatchState: ObservableObject {
    @Published private(set) var entries: [WildBatchItem] = []
    @Published private(set) var running = false
    @Published private(set) var completed = 0
    @Published var status = "选择多张图片，逐张进行本机 OCR"
    private var active: Task<Void, Never>?
    static let maxItems = 24
    static let maxBytesPerImage = 16_000_000
    static let maxSessionImageBytes = 96_000_000

    func add(_ images: [(name: String, data: Data)]) {
        guard !running else { return }
        var rejected = 0
        var totalBytes = entries.reduce(0) { $0 + $1.bytes.count }
        for image in images {
            guard entries.count < Self.maxItems,
                  totalBytes + image.data.count <= Self.maxSessionImageBytes,
                  image.data.count <= Self.maxBytesPerImage,
                  UIImage(data: image.data)?.cgImage != nil else {
                rejected += 1
                continue
            }
            entries.append(WildBatchItem(name: image.name, bytes: image.data))
            totalBytes += image.data.count
        }
        status = rejected == 0 ? "已导入 \(entries.count) 张" :
            "已导入 \(entries.count) 张；跳过 \(rejected) 张超出图片/会话容量或无法解码的图片"
    }

    func clear() {
        guard !running else { return }
        entries.removeAll()
        completed = 0
        status = "已清除本次批量数据"
    }

    func cancel() {
        active?.cancel()
        status = "正在停止；不会丢失已完成的结果"
    }

    func run(quality: OCRQuality, language: String, region: OCRRegion,
             engineID: String = "apple-vision") {
        guard !running, !entries.isEmpty, region.isValid else { return }
        running = true
        completed = 0
        status = "批量本机 OCR 运行中"
        let selectedQuality = quality
        let selectedEngine = engineID
        let hints = language == "auto" ? [] : [language]
        active = Task { @MainActor [weak self] in
            guard let self else { return }
            for index in entries.indices {
                if Task.isCancelled { break }
                guard entries[index].text.isEmpty else {
                    completed += 1
                    continue
                }
                entries[index].status = "正在识别"
                let imageData = entries[index].bytes
                do {
                    let result = try await Task.detached(priority: .userInitiated) {
                        () throws -> ([OCRBlock], Int) in
                        try Task.checkCancellation()
                        guard let image = UIImage(data: imageData), let cg = image.cgImage else {
                            throw NSError(domain: "wild.batch", code: 1,
                                userInfo: [NSLocalizedDescriptionKey: "图片解码失败"])
                        }
                        let orientation = image.imageOrientation.wildCGOrientation
                        let start = ProcessInfo.processInfo.systemUptime
                        let blocks: [OCRBlock]
                        #if WILD_OCR_PADDLE
                        if selectedEngine == "paddle-onnx" {
                            blocks = try await WildPaddleRuntime.shared.recognize(
                                image, region: region).blocks
                        } else {
                            blocks = try AppleVisionOCR.recognize(
                                cg, orientation: orientation, region: region,
                                languageHints: hints, quality: selectedQuality)
                        }
                        #else
                        blocks = try AppleVisionOCR.recognize(
                            cg, orientation: orientation, region: region,
                            languageHints: hints, quality: selectedQuality)
                        #endif
                        return (blocks, max(0, Int(1000 *
                            (ProcessInfo.processInfo.systemUptime - start))))
                    }.value
                    if Task.isCancelled { break }
                    entries[index].text = result.0.map(\.text).joined(separator: "\n")
                    entries[index].blockCount = result.0.count
                    entries[index].elapsedMs = result.1
                    entries[index].status = "已完成"
                    completed += 1
                } catch {
                    if Task.isCancelled { break }
                    entries[index].status = "失败"
                    entries[index].failure = error.localizedDescription
                    completed += 1
                }
            }
            running = false
            active = nil
            status = completed == entries.count ?
                "批量完成 · \(completed)/\(entries.count)" :
                "已停止 · 完成 \(completed)/\(entries.count)"
        }
    }

    var exportText: String {
        entries.filter { !$0.text.isEmpty }.map {
            "=== " + $0.name + " ===\n" + $0.text
        }.joined(separator: "\n\n")
    }

    var aggregateLatencyMs: Int {
        entries.filter { $0.elapsedMs > 0 }.reduce(0) { $0 + $1.elapsedMs }
    }
}

private extension UIImage.Orientation {
    var wildCGOrientation: CGImagePropertyOrientation {
        switch self {
        case .up: return .up
        case .down: return .down
        case .left: return .left
        case .right: return .right
        case .upMirrored: return .upMirrored
        case .downMirrored: return .downMirrored
        case .leftMirrored: return .leftMirrored
        case .rightMirrored: return .rightMirrored
        @unknown default: return .up
        }
    }
}

struct WildBatchScreen: View {
    @StateObject private var batch = WildBatchState()
    @State private var images: [PhotosPickerItem] = []
    @State private var importFiles = false
    let quality: OCRQuality
    let language: String
    let region: OCRRegion
    let engineID: String

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                Text("批量文字识别").font(.system(size: 27, weight: .bold, design: .rounded))
                Text("依次在 iPhone 本机识别最多 24 张图片。识别结果只保留在当前会话；不上传到网络。")
                    .font(.subheadline).foregroundStyle(.secondary)
                HStack {
                    PhotosPicker(selection: $images, maxSelectionCount: 24, matching: .images) {
                        Label("选择多张", systemImage: "photo.on.rectangle.angled")
                    }.buttonStyle(.borderedProminent)
                    Button { importFiles = true } label: {
                        Label("导入文件", systemImage: "folder")
                    }.buttonStyle(.bordered)
                }
                .disabled(batch.running)
                HStack {
                    Text("图片 \(batch.entries.count)/24")
                    Spacer()
                    Text("完成 \(batch.completed) 张")
                }
                .font(.footnote.monospacedDigit()).foregroundStyle(.secondary)
                if batch.running {
                    ProgressView(value: Double(batch.completed),
                                 total: Double(max(1, batch.entries.count)))
                }
                Text(batch.status).font(.footnote)
                    .foregroundStyle(.secondary)

                HStack(spacing: 12) {
                    if batch.running {
                        Button("停止识别", role: .cancel) { batch.cancel() }
                            .buttonStyle(.borderedProminent)
                    } else {
                        Button {
                            batch.run(quality: quality, language: language, region: region,
                                      engineID: engineID)
                        } label: {
                            Label("开始批量 OCR", systemImage: "text.viewfinder")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(batch.entries.isEmpty)
                        Button("清空", role: .destructive) { batch.clear() }
                            .buttonStyle(.bordered)
                    }
                }

                if !batch.exportText.isEmpty {
                    ShareLink(item: batch.exportText) {
                        Label("分享全部已识别文字", systemImage: "square.and.arrow.up")
                    }.buttonStyle(.bordered)
                }
                ForEach(batch.entries) { item in
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(item.name).font(.headline).lineLimit(1)
                            Spacer()
                            Text(item.status)
                                .font(.caption)
                                .foregroundStyle(item.failure == nil ? Color.secondary : Color.red)
                        }
                        if let failure = item.failure {
                            Text(failure).font(.caption).foregroundStyle(.red)
                        }
                        if !item.text.isEmpty {
                            Text(item.text)
                                .font(.subheadline)
                                .textSelection(.enabled)
                                .lineLimit(6)
                        }
                        HStack {
                            Text("\(item.blockCount) 行 · \(item.elapsedMs)ms")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                            Spacer()
                            if !item.text.isEmpty {
                                Button("复制") { UIPasteboard.general.string = item.text }
                                    .font(.caption)
                            }
                        }
                    }
                    .padding(15)
                    .background(Color(uiColor: .secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 18))
                }
            }
            .padding(18)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("批量 OCR")
        .fileImporter(isPresented: $importFiles, allowedContentTypes: [.image],
                      allowsMultipleSelection: true) { outcome in
            do {
                let urls = try outcome.get()
                var added: [(name: String, data: Data)] = []
                for url in urls.prefix(24) {
                    let hasAccess = url.startAccessingSecurityScopedResource()
                    defer { if hasAccess { url.stopAccessingSecurityScopedResource() } }
                    let values = try url.resourceValues(forKeys: [.fileSizeKey])
                    guard (values.fileSize ?? Int.max) <= WildBatchState.maxBytesPerImage else { continue }
                    added.append((url.lastPathComponent, try Data(contentsOf: url)))
                }
                batch.add(added)
            } catch { batch.status = "文件导入失败：" + error.localizedDescription }
        }
        .onChange(of: images) { _, selection in
            guard !selection.isEmpty else { return }
            Task {
                var loaded: [(name: String, data: Data)] = []
                for (index, item) in selection.enumerated() {
                    if let data = try? await item.loadTransferable(type: Data.self) {
                        loaded.append(("相册图片 \(index + 1)", data))
                    }
                }
                batch.add(loaded)
                images = []
            }
        }
    }
}
