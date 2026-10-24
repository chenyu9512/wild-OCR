import SwiftUI
import UIKit

/// Vision uses a normalized lower-left origin. The editor displays its region
/// in screen-space (top-left origin) and converts only at the gesture boundary.
struct WildROIEditor: View {
    @Environment(\.dismiss) private var dismiss
    let picture: UIImage?
    @Binding var region: OCRRegion

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("拖动青色框调整识别范围；拖动右下角圆点改变大小。")
                        .font(.subheadline).foregroundStyle(.secondary)
                    if let image = picture {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .overlay {
                                GeometryReader { geometry in
                                    let size = geometry.size
                                    let bounds = CGRect(
                                        x: region.x * size.width,
                                        y: (1 - region.y - region.height) * size.height,
                                        width: region.width * size.width,
                                        height: region.height * size.height)
                                    ZStack(alignment: .topLeading) {
                                        Color.clear
                                        Rectangle()
                                            .fill(.black.opacity(0.24))
                                            .mask {
                                                Rectangle().fill(.black)
                                                    .overlay(alignment: .topLeading) {
                                                        Rectangle()
                                                            .frame(width: bounds.width,
                                                                   height: bounds.height)
                                                            .offset(x: bounds.minX, y: bounds.minY)
                                                            .blendMode(.destinationOut)
                                                    }
                                            }
                                            .allowsHitTesting(false)
                                        RoundedRectangle(cornerRadius: 5)
                                            .fill(.mint.opacity(0.12))
                                            .overlay {
                                                RoundedRectangle(cornerRadius: 5)
                                                    .stroke(.mint, lineWidth: 2)
                                            }
                                            .frame(width: bounds.width, height: bounds.height)
                                            .position(x: bounds.midX, y: bounds.midY)
                                            .gesture(DragGesture(minimumDistance: 0)
                                                .onChanged { g in
                                                    guard size.width > 0, size.height > 0 else { return }
                                                    let x = clamp(g.location.x / size.width - region.width / 2,
                                                                  min: 0, max: 1 - region.width)
                                                    let topY = clamp(g.location.y / size.height - region.height / 2,
                                                                     min: 0, max: 1 - region.height)
                                                    region = OCRRegion(x: x,
                                                                       y: 1 - topY - region.height,
                                                                       width: region.width,
                                                                       height: region.height)
                                                })
                                        Circle()
                                            .fill(.mint)
                                            .overlay(Circle().stroke(.white, lineWidth: 2))
                                            .frame(width: 27, height: 27)
                                            .position(x: bounds.maxX, y: bounds.maxY)
                                            .gesture(DragGesture(minimumDistance: 0)
                                                .onChanged { g in
                                                    guard size.width > 0, size.height > 0 else { return }
                                                    let width = clamp(g.location.x / size.width - region.x,
                                                                      min: 0.12, max: 1 - region.x)
                                                    let topY = 1 - region.y - region.height
                                                    let height = clamp(g.location.y / size.height - topY,
                                                                       min: 0.12, max: 1 - topY)
                                                    region = OCRRegion(x: region.x,
                                                                       y: 1 - topY - height,
                                                                       width: width, height: height)
                                                })
                                    }
                                }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 13))
                    } else {
                        ContentUnavailableView("还没有图片", systemImage: "photo",
                                               description: Text("请先在识别工作台导入图片"))
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("精确微调").font(.headline)
                        settingSlider("水平位置", value: region.x, maximum: 1 - region.width) {
                            update(x: $0)
                        }
                        settingSlider("垂直位置", value: region.y, maximum: 1 - region.height) {
                            update(y: $0)
                        }
                        settingSlider("区域宽度", value: region.width, maximum: 1 - region.x) {
                            update(width: $0)
                        }
                        settingSlider("区域高度", value: region.height, maximum: 1 - region.y) {
                            update(height: $0)
                        }
                        Text(String(format: "x %.3f · y %.3f · w %.3f · h %.3f",
                                    region.x, region.y, region.width, region.height))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemGroupedBackground),
                                in: RoundedRectangle(cornerRadius: 18))
                    Button("重置为整屏") { region = .full }
                        .buttonStyle(.bordered)
                }
                .padding(18)
            }
            .navigationTitle("编辑扫描区域")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }.fontWeight(.semibold)
                }
            }
        }
    }

    private func settingSlider(_ title: String, value: Double, maximum: Double,
                               update: @escaping (Double) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title).font(.subheadline)
                Spacer()
                Text(String(format: "%.0f%%", value * 100))
                    .font(.caption.monospacedDigit()).foregroundStyle(.secondary)
            }
            Slider(value: Binding(get: { value },
                                  set: { update($0) }),
                   in: 0...max(0.001, maximum))
                .tint(.mint)
        }
    }

    private func update(x: Double? = nil, y: Double? = nil,
                        width: Double? = nil, height: Double? = nil) {
        let xValue = clamp(x ?? region.x, min: 0, max: 1 - region.width)
        let yValue = clamp(y ?? region.y, min: 0, max: 1 - region.height)
        let newWidth = clamp(width ?? region.width, min: 0.12, max: 1 - xValue)
        let newHeight = clamp(height ?? region.height, min: 0.12, max: 1 - yValue)
        region = OCRRegion(x: xValue, y: yValue, width: newWidth, height: newHeight)
    }

    private func clamp(_ value: Double, min lower: Double, max upper: Double) -> Double {
        Swift.min(Swift.max(value, lower), Swift.max(lower, upper))
    }
}
