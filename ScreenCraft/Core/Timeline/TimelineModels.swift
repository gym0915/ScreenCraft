import Foundation

// TrimRange 记录导出时保留的时间范围，默认会覆盖整段录制。
struct TrimRange: Codable, Equatable {
    var start: TimeInterval
    var end: TimeInterval

    init(start: TimeInterval, end: TimeInterval) {
        self.start = start
        self.end = end
    }
}

// Timeline 是编辑器核心数据模型，先只保存剪辑、缩放段和展示样式。
struct Timeline: Codable, Equatable {
    var duration: TimeInterval
    var trim: TrimRange
    var zoomSegments: [ZoomSegment]
    var style: ProjectStyle

    init(
        duration: TimeInterval = 0,
        trim: TrimRange? = nil,
        zoomSegments: [ZoomSegment] = [],
        style: ProjectStyle = .default
    ) {
        self.duration = duration
        // 未传入 trim 时使用完整时长，避免新项目出现空导出范围。
        self.trim = trim ?? TrimRange(start: 0, end: duration)
        self.zoomSegments = zoomSegments
        self.style = style
    }
}
