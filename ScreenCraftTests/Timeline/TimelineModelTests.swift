import CoreGraphics
import Testing
@testable import ScreenCraft

@MainActor
struct TimelineModelTests {
    @Test func defaultTimelineStartsWithoutZoomSegments() {
        // 新时间线不能隐式生成缩放段，避免基础项目出现无法解释的编辑效果。
        let timeline = Timeline(duration: 12)

        #expect(timeline.duration == 12)
        #expect(timeline.trim == TrimRange(start: 0, end: 12))
        #expect(timeline.zoomSegments.isEmpty)
    }

    @Test func defaultProjectStyleUsesReasonablePresentationValues() {
        // 默认样式是导出预览的基线，测试锁定这些值以便后续调整可被审查。
        let style = ProjectStyle.default

        #expect(style.background == "#101014")
        #expect(style.padding == 48)
        #expect(style.cornerRadius == 24)
        #expect(style.shadow.radius == 24)
        #expect(style.cursorScale == 1)
    }

    @Test func timelinePreviewMapsZoomSegmentsToClampedFractions() {
        let timeline = Timeline(
            duration: 10,
            zoomSegments: [
                ZoomSegment(
                    start: -1,
                    end: 2,
                    targetRect: .zero,
                    scale: 1.8,
                    source: .automatic
                ),
                ZoomSegment(
                    start: 4,
                    end: 12,
                    targetRect: .zero,
                    scale: 2.2,
                    source: .manual
                )
            ]
        )

        let preview = timeline.preview

        #expect(preview.durationLabel == "10.0s")
        #expect(preview.segments.count == 2)
        #expect(preview.segments[0].startFraction == 0)
        #expect(preview.segments[0].widthFraction == 0.2)
        #expect(preview.segments[0].sourceLabel == "Auto")
        #expect(preview.segments[0].scaleLabel == "1.8x")
        #expect(preview.segments[1].startFraction == 0.4)
        #expect(preview.segments[1].widthFraction == 0.6)
        #expect(preview.segments[1].sourceLabel == "Manual")
    }
}
