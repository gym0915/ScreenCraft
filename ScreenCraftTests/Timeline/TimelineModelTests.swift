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
}
