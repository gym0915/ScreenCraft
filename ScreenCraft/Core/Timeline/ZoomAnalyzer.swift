import CoreGraphics
import Foundation

// ZoomAnalysisConfiguration 集中保存自动缩放策略，后续 UI 可以把这些值暴露为项目级偏好。
struct ZoomAnalysisConfiguration: Equatable {
    var isEnabled: Bool
    var recordingSize: MouseEventSize
    var scale: Double
    var segmentDuration: TimeInterval
    var leadInDuration: TimeInterval
    var mergeInterval: TimeInterval
    var mergeDistance: Double

    init(
        isEnabled: Bool = true,
        recordingSize: MouseEventSize,
        scale: Double = 1.6,
        segmentDuration: TimeInterval = 1.2,
        leadInDuration: TimeInterval = 0.15,
        mergeInterval: TimeInterval = 0.6,
        mergeDistance: Double = 120
    ) {
        self.isEnabled = isEnabled
        self.recordingSize = recordingSize
        self.scale = scale
        self.segmentDuration = segmentDuration
        self.leadInDuration = leadInDuration
        self.mergeInterval = mergeInterval
        self.mergeDistance = mergeDistance
    }
}

struct ZoomAnalyzer {
    let configuration: ZoomAnalysisConfiguration

    func segments(from events: [MouseEvent]) -> [ZoomSegment] {
        // 关闭自动缩放时不删除既有 timeline 数据，只阻止本次分析生成新的 automatic segments。
        guard configuration.isEnabled else {
            return []
        }

        let clickSegments = events
            .sorted { $0.timestamp < $1.timestamp }
            .compactMap(segment)

        return clickSegments.reduce(into: []) { segments, nextSegment in
            guard var previous = segments.popLast() else {
                segments.append(nextSegment)
                return
            }

            if shouldMerge(previous, nextSegment) {
                previous.end = max(previous.end, nextSegment.end)
                segments.append(previous)
                return
            }

            var adjustedSegment = nextSegment
            if adjustedSegment.start < previous.end {
                adjustedSegment.start = previous.end
            }
            segments.append(previous)
            segments.append(adjustedSegment)
        }
    }

    private func segment(from event: MouseEvent) -> ZoomSegment? {
        // 只有真实点击能触发自动缩放；move/drag 事件只作为后续光标轨或热区分析输入。
        guard event.kind == .leftClick || event.kind == .rightClick,
              let location = event.recordingLocation
        else {
            return nil
        }

        // 缩放提前一点进入，让点击动作发生时画面已经稳定聚焦。
        let start = max(0, event.timestamp - configuration.leadInDuration)
        let end = event.timestamp + configuration.segmentDuration - configuration.leadInDuration

        return ZoomSegment(
            start: start,
            end: end,
            targetRect: targetRect(centeredAt: location),
            scale: configuration.scale,
            source: .automatic
        )
    }

    private func shouldMerge(_ previous: ZoomSegment, _ next: ZoomSegment) -> Bool {
        // 近距离连续点击通常属于同一个操作焦点，合并能避免快速来回缩放造成跳动。
        let timeGap = next.start - previous.end
        return timeGap <= configuration.mergeInterval
            && centerDistance(previous.targetRect, next.targetRect) <= configuration.mergeDistance
    }

    private func targetRect(centeredAt location: MouseEventLocation) -> CGRect {
        // targetRect 固定尺寸，只移动原点；边缘点击通过 clamp 保持画面内，不靠改变缩放框大小补黑边。
        let width = configuration.recordingSize.width / configuration.scale
        let height = configuration.recordingSize.height / configuration.scale
        let maxX = max(0, configuration.recordingSize.width - width)
        let maxY = max(0, configuration.recordingSize.height - height)
        let originX = clamp(location.x - width / 2, lowerBound: 0, upperBound: maxX)
        let originY = clamp(location.y - height / 2, lowerBound: 0, upperBound: maxY)

        return CGRect(x: originX, y: originY, width: width, height: height)
    }

    private func centerDistance(_ lhs: CGRect, _ rhs: CGRect) -> Double {
        let dx = lhs.midX - rhs.midX
        let dy = lhs.midY - rhs.midY
        return sqrt(dx * dx + dy * dy)
    }

    private func clamp(_ value: Double, lowerBound: Double, upperBound: Double) -> Double {
        min(max(value, lowerBound), upperBound)
    }
}
