import CoreGraphics
import Foundation

// source 区分人工添加和后续自动检测，便于 UI 提供不同的编辑/撤销语义。
enum ZoomSegmentSource: String, Codable, Equatable {
    case manual
    case automatic
}

// ZoomSegment 只保存时间和目标区域，不直接持有视频帧或视图状态。
struct ZoomSegment: Identifiable, Codable, Equatable {
    let id: UUID
    var start: TimeInterval
    var end: TimeInterval
    var targetRect: CGRect
    var scale: Double
    var source: ZoomSegmentSource

    init(
        id: UUID = UUID(),
        start: TimeInterval,
        end: TimeInterval,
        targetRect: CGRect,
        scale: Double,
        source: ZoomSegmentSource = .manual
    ) {
        self.id = id
        self.start = start
        self.end = end
        self.targetRect = targetRect
        self.scale = scale
        self.source = source
    }
}
