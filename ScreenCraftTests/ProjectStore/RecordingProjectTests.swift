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

    @Test func projectMediaStoresPackageRelativePaths() {
        let media = ProjectMedia(
            screenVideoPath: "media/screen.mov",
            microphoneAudioPath: "media/microphone.m4a",
            mouseEventsPath: "events/mouse-events.json"
        )

        #expect(media.screenVideoPath == "media/screen.mov")
        #expect(media.microphoneAudioPath == "media/microphone.m4a")
        #expect(media.mouseEventsPath == "events/mouse-events.json")
    }

    @Test func recordingProjectStartsWithDefaultMediaAndTimeline() {
        // 便捷初始化应生成可编辑项目，同时保持 camera 轨道为空。
        let project = RecordingProject(name: "Untitled", duration: 8)

        #expect(project.name == "Untitled")
        #expect(project.media.cameraVideoURL == nil)
        #expect(project.timeline.duration == 8)
        #expect(project.timeline.zoomSegments.isEmpty)
    }

    @Test func recordingProjectStoresCaptureSourceMetadata() {
        let source = RecordingSourceMetadata(
            id: "window-42",
            kind: .window,
            title: "Demo",
            appName: "Safari",
            geometry: CaptureSourceGeometry(originX: 10, originY: 20, width: 640, height: 360, scale: 2),
            captureResolution: CaptureResolution(width: 1280, height: 720)
        )
        let project = RecordingProject(name: "Window Recording", source: source, duration: 12)

        #expect(project.source == source)
        #expect(project.source?.captureResolution == CaptureResolution(width: 1280, height: 720))
    }
}
