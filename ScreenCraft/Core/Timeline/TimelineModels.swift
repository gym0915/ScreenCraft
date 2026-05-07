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

struct TimelinePreview: Equatable {
    var duration: TimeInterval
    var durationLabel: String
    var trimLabel: String
    var segments: [TimelinePreviewSegment]
}

struct TimelinePreviewSegment: Identifiable, Equatable {
    let id: UUID
    var startFraction: Double
    var widthFraction: Double
    var startLabel: String
    var endLabel: String
    var scaleLabel: String
    var sourceLabel: String
}

extension Timeline {
    var preview: TimelinePreview {
        let safeDuration = max(duration, 0)
        let segments = zoomSegments
            .sorted { $0.start < $1.start }
            .map { segment in
                previewSegment(for: segment, duration: safeDuration)
            }

        return TimelinePreview(
            duration: safeDuration,
            durationLabel: Self.timeLabel(safeDuration),
            trimLabel: "\(Self.timeLabel(trim.start)) - \(Self.timeLabel(trim.end))",
            segments: segments
        )
    }

    private func previewSegment(for segment: ZoomSegment, duration: TimeInterval) -> TimelinePreviewSegment {
        let clampedStart = Self.clamp(segment.start, lowerBound: 0, upperBound: duration)
        let clampedEnd = Self.clamp(segment.end, lowerBound: clampedStart, upperBound: duration)
        let startFraction = duration > 0 ? clampedStart / duration : 0
        let widthFraction = duration > 0 ? max((clampedEnd - clampedStart) / duration, 0) : 0

        return TimelinePreviewSegment(
            id: segment.id,
            startFraction: startFraction,
            widthFraction: widthFraction,
            startLabel: Self.timeLabel(segment.start),
            endLabel: Self.timeLabel(segment.end),
            scaleLabel: String(format: "%.1fx", segment.scale),
            sourceLabel: segment.source.previewLabel
        )
    }

    private static func clamp(_ value: TimeInterval, lowerBound: TimeInterval, upperBound: TimeInterval) -> TimeInterval {
        min(max(value, lowerBound), upperBound)
    }

    private static func timeLabel(_ time: TimeInterval) -> String {
        String(format: "%.1fs", time)
    }
}
