import Foundation
import Testing
@testable import ScreenCraft

@MainActor
struct RecordingProjectTests {
    @Test func projectMediaKeepsCameraTrackOptionalByDefault() {
        // 媒体轨道默认全部为空，确保新项目不会假定任何采集结果已经存在。
        let media = ProjectMedia()

        #expect(media.screenVideoURL == nil)
        #expect(media.microphoneAudioURL == nil)
        #expect(media.cameraVideoURL == nil)
    }

    @Test func recordingProjectStartsWithDefaultMediaAndTimeline() {
        // 便捷初始化应生成可编辑项目，同时保持 camera 轨道为空。
        let project = RecordingProject(name: "Untitled", duration: 8)

        #expect(project.name == "Untitled")
        #expect(project.media.cameraVideoURL == nil)
        #expect(project.timeline.duration == 8)
        #expect(project.timeline.zoomSegments.isEmpty)
    }
}
