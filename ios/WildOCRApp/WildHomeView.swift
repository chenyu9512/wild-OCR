import SwiftUI
import PhotosUI
import UniformTypeIdentifiers
import UIKit

// MARK: - Design language

private enum WildPalette {
    static let mint = Color(red: 0.10, green: 0.79, blue: 0.68)
    static let violet = Color(red: 0.54, green: 0.45, blue: 0.99)
    static let blue = Color(red: 0.27, green: 0.58, blue: 0.96)
    static let background = Color(uiColor: .systemGroupedBackground)
    static let surface = Color(uiColor: .secondarySystemGroupedBackground)
    static let divider = Color.primary.opacity(0.07)
}

private struct WildSurface<Content: View>: View {
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 15) { content }
            .padding(17)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(WildPalette.surface, in: RoundedRectangle(cornerRadius: 22))
            .overlay(RoundedRectangle(cornerRadius: 22)
                .strokeBorder(WildPalette.divider, lineWidth: 1))
    }
}

private struct WildHeading: View {
    let eyebrow: String
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(eyebrow.uppercased())
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .tracking(2.4)
                .foregroundStyle(WildPalette.mint)
            Text(title)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .tracking(-0.9)
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct WildSectionTitle: View {
    let title: String
    let icon: String
    var detail: String? = nil
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(WildPalette.mint)
            Text(title).font(.system(.headline, design: .rounded))
            Spacer()
            if let detail {
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

private struct WildPill: View {
    let text: String
    let icon: String
    var tint: Color = WildPalette.mint
    var body: some View {
        Label(text, systemImage: icon)
            .font(.system(size: 11, weight: .semibold, design: .rounded))
            .foregroundStyle(tint)
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(tint.opacity(0.12), in: Capsule())
    }
}

private struct WildStat: View {
    let number: String
    let caption: String
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(number)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(caption).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct WildEmptyState: View {
    let icon: String
    let title: String
    let message: String
    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(WildPalette.mint)
                .padding(18)
                .background(WildPalette.mint.opacity(0.09), in: Circle())
            Text(title).font(.headline)
            Text(message)
                .font(.footnote).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 14)
    }
}

private struct WildPrimaryButton: View {
    let title: String
    let icon: String
    var isDisabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                if isDisabled {
                    ProgressView().tint(Color.black)
                } else {
                    Image(systemName: icon)
                }
                Text(title).fontWeight(.bold)
                Spacer()
                Image(systemName: "arrow.right")
                    .font(.subheadline.weight(.semibold))
            }
            .padding(17)
            .foregroundStyle(Color.black.opacity(isDisabled ? 0.5 : 0.9))
            .background(WildPalette.mint.opacity(isDisabled ? 0.45 : 1),
                        in: RoundedRectangle(cornerRadius: 17))
        }
        .disabled(isDisabled)
        .buttonStyle(.plain)
    }
}

// MARK: - Root shell

struct WildHomeView: View {
    @StateObject private var vm = WildAppState()
    @State private var photoPicker: PhotosPickerItem?
    @State private var selectImageFile = false
    @State private var selectModelFolder = false
    @State private var selectComparisonFile = false
    @AppStorage("wildocr.appearance") private var appearance = "dark"

    private var activeScheme: ColorScheme? {
        switch appearance {
        case "light": return .light
        case "dark": return .dark
        default: return nil
        }
    }

    var body: some View {
        TabView {
            NavigationStack {
                WildScanScreen(vm: vm, photoPicker: $photoPicker,
                               openFiles: { selectImageFile = true })
                    .toolbar { settingsButton }
            }
            .tabItem { Label("识别", systemImage: "viewfinder") }

            NavigationStack {
                WildRecordsScreen(vm: vm)
                    .toolbar { settingsButton }
            }
            .tabItem { Label("记录", systemImage: "clock.arrow.circlepath") }

            NavigationStack {
                WildModelsScreen(vm: vm, importFolder: { selectModelFolder = true })
                    .toolbar { settingsButton }
            }
            .tabItem { Label("模型", systemImage: "square.stack.3d.up") }

            NavigationStack {
                WildLabScreen(vm: vm, importReport: { selectComparisonFile = true })
                    .toolbar { settingsButton }
            }
            .tabItem { Label("实验室", systemImage: "chart.xyaxis.line") }
        }
        .tint(WildPalette.mint)
        .preferredColorScheme(activeScheme)
        .fileImporter(isPresented: $selectImageFile, allowedContentTypes: [.image]) {
            acceptFile($0, isImage: true)
        }
        .fileImporter(isPresented: $selectComparisonFile, allowedContentTypes: [.json]) {
            acceptFile($0, isImage: false)
        }
        .fileImporter(isPresented: $selectModelFolder, allowedContentTypes: [.folder]) {
            switch $0 {
            case .success(let url): vm.installFolder(url)
            case .failure(let error): vm.modelStatus = error.localizedDescription
            }
        }
        .onChange(of: photoPicker) { _, item in
            guard let item else { return }
            Task {
                do {
                    if let bytes = try await item.loadTransferable(type: Data.self) {
                        vm.load(bytes)
                    }
                } catch { vm.status = "导入失败：" + error.localizedDescription }
            }
        }
        .onAppear { vm.refreshModels() }
    }

    private var settingsButton: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            NavigationLink {
                WildSettingsScreen(vm: vm, appearance: $appearance)
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 17, weight: .semibold))
                    .accessibilityLabel("设置")
            }
        }
    }

    private func acceptFile(_ result: Result<URL, Error>, isImage: Bool) {
        do {
            let url = try result.get()
            let access = url.startAccessingSecurityScopedResource()
            defer { if access { url.stopAccessingSecurityScopedResource() } }
            let bytes = try Data(contentsOf: url)
            if isImage { vm.load(bytes) }
            else { vm.importPaddleReport(bytes) }
        } catch { vm.status = "导入失败：" + error.localizedDescription }
    }
}

// MARK: - Recognize

private struct WildScanScreen: View {
    @ObservedObject var vm: WildAppState
    @State private var showROIEditor = false
    @Binding var photoPicker: PhotosPickerItem?
    let openFiles: () -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 20) {
                WildHeading(eyebrow: "WILD INTELLIGENCE / OFFLINE FIRST",
                            title: "看见文字，读懂世界。",
                            subtitle: "一个简洁的工作区，完成多语言图片识别、定位与提取。")

                HStack(spacing: 8) {
                    WildPill(text: "本机处理", icon: "iphone.gen3")
                    WildPill(text: "无需 API", icon: "lock.shield", tint: WildPalette.blue)
                }

                previewPanel
                controlsPanel
                NavigationLink {
                    WildBatchScreen(quality: vm.quality, language: vm.selectedLanguage,
                                    region: vm.effectiveRegion, engineID: vm.engineID)
                } label: {
                    Label("批量识别图片", systemImage: "square.stack.3d.down.right")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                }
                .background(WildPalette.surface, in: RoundedRectangle(cornerRadius: 17))

                WildPrimaryButton(
                    title: vm.busy ? "识别正在运行" : "开始识别",
                    icon: "text.viewfinder",
                    isDisabled: vm.busy || vm.photo == nil,
                    action: { vm.recognize() })

                WildSurface {
                    WildSectionTitle(title: "运行状态", icon: "waveform.path.ecg",
                                     detail: "APPLE VISION")
                    Text(vm.status)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 12) {
                        WildStat(number: "\(vm.measuredMs)ms", caption: "最近一次 OCR")
                        WildStat(number: "\(vm.rows.count)", caption: "已识别文字块")
                        WildStat(number: "\(vm.text.count)", caption: "提取字符")
                    }
                    if vm.summary != "尚未测试" {
                        Text(vm.summary)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(WildPalette.mint)
                    }
                }

                resultsPanel
                Text("文字与图片默认只在设备内处理。记录需手动保存，退出 App 后自动消失。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal, 19)
            .padding(.top, 15)
            .padding(.bottom, 35)
        }
        .background(WildPalette.background)
        .navigationTitle("wild-OCR")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showROIEditor) {
            WildROIEditor(picture: vm.photo, region: $vm.customRegion)
        }
    }

    private var previewPanel: some View {
        WildSurface {
            WildSectionTitle(title: "图片工作台", icon: "photo.artframe",
                             detail: vm.photo == nil ? "等待输入" : "已载入")
            if let photo = vm.photo {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFit()
                    .overlay {
                        if vm.showBoxes && !vm.rows.isEmpty {
                            GeometryReader { geometry in
                                ForEach(vm.rows.indices, id: \.self) { index in
                                    let rect = vm.rows[index].region
                                    RoundedRectangle(cornerRadius: 3)
                                        .stroke(WildPalette.mint, lineWidth: 1.5)
                                        .background(WildPalette.mint.opacity(0.08))
                                        .frame(
                                            width: geometry.size.width * rect.width,
                                            height: geometry.size.height * rect.height)
                                        .position(
                                            x: geometry.size.width * (rect.x + rect.width / 2),
                                            y: geometry.size.height * (1 - rect.y - rect.height / 2))
                                }
                            }
                            .allowsHitTesting(false)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: 310)
                    .clipShape(RoundedRectangle(cornerRadius: 13))
                    .accessibilityLabel("已导入图片和识别文字框")
            } else {
                WildEmptyState(icon: "photo.badge.plus",
                               title: "导入图片，开始提取文字",
                               message: "支持相册截图及文件图片；不上传云端。")
            }
            HStack(spacing: 12) {
                PhotosPicker(selection: $photoPicker, matching: .images) {
                    Label("相册", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                Button(action: openFiles) {
                    Label("文件", systemImage: "folder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var controlsPanel: some View {
        WildSurface {
            WildSectionTitle(title: "识别参数", icon: "switch.2", detail: "按任务调整")
            #if WILD_OCR_PADDLE
            Picker("OCR 引擎", selection: $vm.engineID) {
                Text("Apple Vision").tag("apple-vision")
                Text("PaddleOCR · \(WildPaddleRuntime.bundledModelPreset)").tag("paddle-onnx")
            }
            .pickerStyle(.segmented)
            if vm.engineID == "paddle-onnx" {
                Text("当前内置 \(WildPaddleRuntime.bundledModelPreset) 模型。首次识别会加载 ONNX 资源；质量选项只影响 Vision。")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            #endif
            Picker("识别质量", selection: $vm.quality) {
                Text("快速").tag(OCRQuality.fast)
                Text("高精度").tag(OCRQuality.accurate)
            }
            .pickerStyle(.segmented)

            HStack {
                Label("源语言", systemImage: "character.bubble")
                Spacer()
                Picker("源语言", selection: $vm.selectedLanguage) {
                    Text("自动识别").tag("auto")
                    Text("简体中文").tag("zh-Hans")
                    Text("繁體中文").tag("zh-Hant")
                    Text("日本語").tag("ja-JP")
                    Text("한국어").tag("ko-KR")
                    Text("English").tag("en-US")
                    Text("Русский").tag("ru-RU")
                    Text("Español").tag("es-ES")
                    Text("Français").tag("fr-FR")
                    Text("Deutsch").tag("de-DE")
                    Text("العربية").tag("ar-SA")
                    Text("ภาษาไทย").tag("th-TH")
                }
                .labelsHidden()
                .tint(WildPalette.mint)
            }
            Divider().opacity(0.4)
            HStack {
                Label("扫描区域", systemImage: "crop.rotate")
                Spacer()
                Picker("扫描区域", selection: $vm.scanArea) {
                    ForEach(WildOCRScanArea.allCases) { area in
                        Text(area.title).tag(area)
                    }
                }
                .labelsHidden()
                .tint(WildPalette.mint)
            }
            if vm.scanArea == .custom {
                Button {
                    showROIEditor = true
                } label: {
                    Label("拖动调整识别区域", systemImage: "crop")
                }
                .buttonStyle(.bordered)
            }
            Toggle(isOn: $vm.showBoxes) {
                Label("显示文字定位框", systemImage: "square.dashed")
            }
            .tint(WildPalette.mint)
            Text("语言可用性由 iOS Vision 识别模型决定；不支持的语言提示将安全回退自动检测。")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private var resultsPanel: some View {
        WildSurface {
            WildSectionTitle(title: "提取结果", icon: "doc.text.magnifyingglass",
                             detail: "\(vm.rows.count) 个文字块")
            if vm.text.isEmpty {
                WildEmptyState(icon: "text.alignleft",
                               title: "结果将在这里显示",
                               message: "识别后可以复制、分享或加入本次记录。")
            } else {
                HStack(spacing: 10) {
                    Button {
                        UIPasteboard.general.string = vm.text
                    } label: {
                        Label("复制全文", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.borderedProminent)
                    ShareLink(item: vm.text) {
                        Label("分享文字", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                }
                HStack {
                    Button {
                        vm.saveCurrentResult()
                    } label: {
                        Label("存入记录", systemImage: "bookmark")
                    }
                    .buttonStyle(.bordered)
                    Button("清空结果", role: .destructive) {
                        vm.clearCurrentResult()
                    }
                    .buttonStyle(.bordered)
                }
                Text(vm.text)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(13)
                    .background(WildPalette.background, in: RoundedRectangle(cornerRadius: 12))

                DisclosureGroup("逐行详情与坐标") {
                    LazyVStack(alignment: .leading, spacing: 10) {
                        ForEach(vm.rows.indices, id: \.self) { index in
                            let line = vm.rows[index]
                            VStack(alignment: .leading, spacing: 5) {
                                HStack {
                                    Text(String(format: "%02d", index + 1))
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(WildPalette.mint)
                                    Text(line.script.rawValue)
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    if let confidence = line.confidence {
                                        Text(String(format: "%.0f%%", confidence * 100))
                                            .font(.caption2.monospacedDigit())
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Text(line.text).font(.subheadline)
                                    .textSelection(.enabled)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 4)
                            if index < vm.rows.count - 1 { Divider().opacity(0.4) }
                        }
                    }
                }
                .tint(WildPalette.mint)
            }
        }
    }
}

// MARK: - Session records

private struct WildRecordsScreen: View {
    @ObservedObject var vm: WildAppState
    @State private var confirmClear = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                WildHeading(eyebrow: "YOUR WORKSPACE",
                            title: "本次识别记录",
                            subtitle: "只保存你主动收藏的结果。本次会话结束后，不会写入持久历史。")
                HStack {
                    WildPill(text: "\(vm.savedSessions.count) 条已保存", icon: "bookmark")
                    Spacer()
                    if !vm.savedSessions.isEmpty {
                        Button("全部清除", role: .destructive) { confirmClear = true }
                            .font(.footnote)
                    }
                }

                if vm.savedSessions.isEmpty {
                    WildSurface {
                        WildEmptyState(icon: "tray",
                                       title: "还没有保存记录",
                                       message: "识别图片后，点「存入记录」即可在这里查看。")
                    }
                } else {
                    ForEach(vm.savedSessions) { item in
                        WildSurface {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(item.createdAt.formatted(
                                        date: .abbreviated, time: .shortened))
                                        .font(.subheadline.weight(.semibold))
                                    Text("\(item.blockCount) 行 · \(item.durationMs)ms · \(item.quality)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Menu {
                                    Button {
                                        UIPasteboard.general.string = item.text
                                    } label: { Label("复制文字", systemImage: "doc.on.doc") }
                                    ShareLink(item: item.text) {
                                        Label("分享文字", systemImage: "square.and.arrow.up")
                                    }
                                    Button(role: .destructive) {
                                        vm.removeSession(item.id)
                                    } label: { Label("删除", systemImage: "trash") }
                                } label: {
                                    Image(systemName: "ellipsis.circle")
                                        .font(.title3)
                                }
                            }
                            Text(item.text)
                                .font(.subheadline)
                                .lineLimit(6)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                }
            }
            .padding(19)
            .padding(.bottom, 30)
        }
        .background(WildPalette.background)
        .navigationTitle("记录")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("清空全部会话记录？", isPresented: $confirmClear) {
            Button("清空记录", role: .destructive) { vm.clearSessions() }
        } message: {
            Text("此操作不能撤销。")
        }
    }
}

// MARK: - Model center

private struct WildModelsScreen: View {
    @ObservedObject var vm: WildAppState
    let importFolder: () -> Void
    @State private var pendingDeletion: WildOCRModelPack?
    @State private var confirmDeletion = false

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 19) {
                WildHeading(eyebrow: "ENGINE LIBRARY",
                            title: "模型中心",
                            subtitle: "统一管理本机识别能力、模型包与文件完整性。")

                WildSurface {
                    WildSectionTitle(title: "当前可用引擎", icon: "cpu", detail: "默认")
                    HStack(spacing: 13) {
                        Image(systemName: "viewfinder")
                            .font(.title2)
                            .foregroundStyle(WildPalette.mint)
                            .frame(width: 48, height: 48)
                            .background(WildPalette.mint.opacity(0.12),
                                        in: RoundedRectangle(cornerRadius: 14))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Apple Vision").font(.headline)
                            Text("iPhone 本地 OCR · Fast / Accurate")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "checkmark.seal.fill")
                            .foregroundStyle(WildPalette.mint)
                    }
                    WildPill(text: "已集成，可用于识别", icon: "checkmark.circle")
                }

                WildSurface {
                    WildSectionTitle(title: "PaddleOCR 多语言模型", icon: "shippingbox",
                                     detail: "实验能力")
                    Text("可导入含 manifest.json 的模型文件夹，离线验证体积与 SHA-256。验证通过不代表已接入模型推理；目前无法在 wild-OCR 内直接运行 PaddleOCR。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    WildPrimaryButton(title: "导入模型包", icon: "square.and.arrow.down",
                                      isDisabled: vm.busy,
                                      action: importFolder)
                    Text(vm.modelStatus)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack {
                        WildStat(number: "\(vm.packs.count)", caption: "已验证模型包")
                        #if WILD_OCR_PADDLE
                        WildStat(number: "1", caption: "内置 Paddle 引擎")
                        #else
                        WildStat(number: "0", caption: "Paddle 可运行引擎")
                        #endif
                    }
                    if !vm.packs.isEmpty {
                        Divider()
                        ForEach(vm.packs, id: \.id) { pack in
                            HStack(spacing: 10) {
                                Image(systemName: "checkmark.shield")
                                    .foregroundStyle(WildPalette.mint)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(pack.displayName).font(.subheadline.weight(.semibold))
                                    Text("文件已校验 · 未接入推理")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button(role: .destructive) {
                                    pendingDeletion = pack
                                    confirmDeletion = true
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                                .accessibilityLabel("删除 \(pack.displayName)")
                            }
                            .padding(.vertical, 7)
                        }
                    }
                }

                WildSurface {
                    WildSectionTitle(title: "可研究的模型系列", icon: "square.stack.3d.up")
                    ForEach(Array(WildOCRModelCatalog.titles.enumerated()), id: \.offset) { index, name in
                        HStack(spacing: 11) {
                            Image(systemName: "cube.transparent")
                                .foregroundStyle(WildPalette.violet)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(name).font(.subheadline.weight(.medium))
                                Text("候选系列 · 不代表当前已安装")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                        }
                        if index < WildOCRModelCatalog.titles.count - 1 {
                            Divider().opacity(0.4)
                        }
                    }
                }
            }
            .padding(19)
            .padding(.bottom, 30)
        }
        .background(WildPalette.background)
        .navigationTitle("模型")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog("删除模型文件？", isPresented: $confirmDeletion) {
            Button("删除", role: .destructive) {
                if let pack = pendingDeletion { vm.deleteModel(pack) }
                pendingDeletion = nil
            }
        } message: {
            Text("将移除设备内该模型包；不会影响 Apple Vision。")
        }
    }
}

// MARK: - Benchmark lab

private struct WildLabScreen: View {
    @ObservedObject var vm: WildAppState
    let importReport: () -> Void

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 19) {
                WildHeading(eyebrow: "PERFORMANCE LAB",
                            title: "性能实验室",
                            subtitle: "不只比较速度，也比较同一张图片上的识别质量。")
                WildSurface {
                    WildSectionTitle(title: "本机 Vision 基准", icon: "speedometer")
                    HStack(spacing: 12) {
                        WildStat(number: "\(vm.measuredMs)ms", caption: "最近一次 OCR")
                        WildStat(number: "\(vm.rows.count)", caption: "识别文字块")
                    }
                    Text(vm.summary)
                        .font(.footnote.monospacedDigit())
                        .foregroundStyle(.secondary)
                    WildPrimaryButton(
                        title: vm.busy ? "测试正在运行" : "运行 5 次 Vision 识别",
                        icon: "play.fill",
                        isDisabled: vm.busy || vm.photo == nil,
                        action: { vm.runVisionBenchmark(repetitions: 5) })
                    if vm.photo == nil {
                        Text("请先在「识别」中导入一张图片。")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                WildSurface {
                    WildSectionTitle(title: "分阶段耗时与热状态", icon: "waveform.path")
                    if let metrics = vm.performanceSummary {
                        HStack(spacing: 8) {
                            WildStat(number: "\(metrics.p50)ms", caption: "总耗时 P50")
                            WildStat(number: "\(metrics.p95)ms", caption: "总耗时 P95")
                            WildStat(number: "\(metrics.max)ms", caption: "最长")
                        }
                        Divider()
                        HStack(spacing: 8) {
                            WildStat(number: "\(metrics.averageDecode)ms", caption: "解码均值")
                            WildStat(number: "\(metrics.averageRecognition)ms", caption: "识别均值")
                            WildStat(number: "\(metrics.count)", caption: "记录样本")
                        }
                        if let recent = vm.performanceSamples.last {
                            Text("最近热状态：\(recent.thermal) · \(recent.configuration)")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        ShareLink(item: vm.performanceCSV) {
                            Label("导出统计 CSV", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(.bordered)
                        Button("清除性能历史", role: .destructive) {
                            vm.clearPerformanceHistory()
                        }
                        .font(.footnote)
                    } else {
                        Text("开始 Vision 测试后，将显示解码、推理、P50/P95、最长延迟与设备热状态。")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }

                #if WILD_OCR_PADDLE
                WildSurface {
                    WildSectionTitle(title: "真机双引擎 A/B", icon: "point.3.connected.trianglepath.dotted")
                    Text("对同一张图片和区域，顺序运行 Vision 与内置 PaddleOCR，并记录各自耗时与识别结果。")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("执行本机 Vision / Paddle 对照") { vm.runIntegratedAB() }
                        .buttonStyle(.borderedProminent)
                        .disabled(vm.busy || vm.photo == nil)
                }
                #endif
                WildSurface {
                    WildSectionTitle(title: "PaddleOCR 外部对照", icon: "arrow.left.arrow.right")
                    WildPill(text: "外部数据，不是本机 Paddle 推理",
                             icon: "info.circle", tint: WildPalette.violet)
                    Text("用官方 PaddleOCR iOS Demo 识别同一张图片，再输入真实耗时与结果。也可以导入包含匹配 SHA-256 的 JSON 报告。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    TextField("Paddle OCR 耗时（毫秒）", text: $vm.externalTime)
                        .keyboardType(.numberPad)
                        .textFieldStyle(.roundedBorder)
                    TextEditor(text: $vm.externalText)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 90)
                        .padding(8)
                        .background(WildPalette.background,
                                    in: RoundedRectangle(cornerRadius: 12))
                        .overlay(alignment: .topLeading) {
                            if vm.externalText.isEmpty {
                                Text("粘贴 PaddleOCR 识别的真实原文")
                                    .foregroundStyle(.tertiary)
                                    .padding(14)
                                    .allowsHitTesting(false)
                            }
                        }
                    HStack(spacing: 12) {
                        Button("记录外部结果") { vm.applyManualPaddle() }
                            .buttonStyle(.borderedProminent)
                        Button("导入 JSON") { importReport() }
                            .buttonStyle(.bordered)
                    }
                    if let external = vm.comparison {
                        Divider()
                        HStack {
                            WildStat(number: "\(vm.measuredMs)ms", caption: "Vision")
                            WildStat(number: "\(external.durationMs)ms", caption: "Paddle 外部")
                        }
                    }
                }

                WildSurface {
                    WildSectionTitle(title: "识别正确率", icon: "checkmark.shield")
                    Text("输入人工核对的正确文字，才能计算 CER（字符错误率）；数值越低越好。")
                        .font(.footnote).foregroundStyle(.secondary)
                    TextField("粘贴正确原文", text: $vm.groundTruth,
                              axis: .vertical)
                        .lineLimit(3...8)
                        .textFieldStyle(.roundedBorder)
                    if let cer = vm.visionCER {
                        metricRow("Apple Vision", value: cer)
                    }
                    if let cer = vm.paddleCER {
                        metricRow("PaddleOCR 外部", value: cer)
                    }
                    if vm.visionCER == nil && vm.paddleCER == nil {
                        Text("尚无可计算的对照数据")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }

                Text("实验室不上传图片、不自动运行网络测试，也不会将外部推理成绩当成 wild-OCR 本机推理成绩。")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            .padding(19)
            .padding(.bottom, 30)
        }
        .background(WildPalette.background)
        .navigationTitle("实验室")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func metricRow(_ title: String, value: Double) -> some View {
        HStack {
            Text(title).font(.subheadline)
            Spacer()
            Text(String(format: "%.1f%%", value * 100))
                .font(.headline.monospacedDigit())
                .foregroundStyle(WildPalette.mint)
        }
    }
}

// MARK: - Settings

private struct WildSettingsScreen: View {
    @ObservedObject var vm: WildAppState
    @Binding var appearance: String
    @State private var confirmClear = false

    var body: some View {
        Form {
            Section("外观") {
                Picker("主题", selection: $appearance) {
                    Text("深色").tag("dark")
                    Text("浅色").tag("light")
                    Text("跟随系统").tag("system")
                }
                Toggle("默认显示 OCR 定位框", isOn: $vm.showBoxes)
                    .tint(WildPalette.mint)
            }
            Section("隐私与记录") {
                Label("识别仅在设备端执行", systemImage: "lock.iphone")
                Label("本次识别记录不会写入持久存储",
                      systemImage: "externaldrive.badge.xmark")
                Button("清空本次识别记录", role: .destructive) {
                    confirmClear = true
                }
            }
            Section("当前能力") {
                LabeledContent("通用 OCR", value: "Apple Vision")
                #if WILD_OCR_PADDLE
                LabeledContent("PaddleOCR", value: "真实本机 ONNX 推理（实验）")
                #else
                LabeledContent("PaddleOCR", value: "文件校验 / 尚未推理")
                #endif
                LabeledContent("对照实验", value: "Vision + 外部报告")
                LabeledContent("版本", value: "0.4.0")
            }
            Section {
                Text("wild-OCR 保持离线优先。新增模型只有完成推理集成、语言覆盖验证和真机基准后才会显示为可用。")
                    .font(.footnote).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("偏好设置")
        .confirmationDialog("清空本次会话记录？", isPresented: $confirmClear) {
            Button("清空", role: .destructive) { vm.clearSessions() }
        }
    }
}
