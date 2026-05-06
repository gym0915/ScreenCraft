import Foundation
import Testing
@testable import ScreenCraft

@MainActor
struct MockServiceTests {
    @Test func mockScreenCaptureServiceStartsIdle() async {
        let service = MockScreenCaptureService()

        // mock 不能触发任何屏幕录制权限请求；初始状态必须稳定为空闲。
        let state = await service.recordingState()

        #expect(state == .idle)
    }

    @Test func mockScreenCaptureServiceSupportsSpikeRecordingFlow() async throws {
        let service = MockScreenCaptureService()

        // mock 录制流程让 HomeViewModel 可以测试 UI 状态机，不访问 ScreenCaptureKit。
        let sources = try await service.availableSources()
        let configuration = ScreenRecordingConfiguration(
            source: try #require(sources.first),
            outputDirectory: URL(fileURLWithPath: "/tmp/screencraft-tests", isDirectory: true)
        )

        try await service.startRecording(configuration: configuration)
        #expect(await service.recordingState() == .recording)

        let project = try await service.stopRecording()
        #expect(project.media.screenVideoURL?.lastPathComponent.hasSuffix(".mov") == true)
        #expect(await service.recordingState() == .idle)
    }

    @Test func mockAudioInputServiceProvidesPlaceholderDevice() async {
        let service = MockAudioInputService()

        // 占位设备让服务边界可测试，同时不依赖开发机是否接入麦克风。
        let devices = await service.availableInputDevices()

        #expect(devices == [AudioInputDevice(id: "mock-microphone", name: "Mock Microphone", isDefault: true)])
    }

    @Test func mockMouseEventServiceStartsWithoutEvents() async {
        let service = MockMouseEventService()

        // 基础脚手架阶段不监听真实鼠标事件，mock 默认应保持空数据。
        let events = await service.recordedEvents()

        #expect(events.isEmpty)
    }

    @Test func mockProjectStorePersistsProjectsInMemory() async throws {
        let store = MockProjectStore()
        let project = RecordingProject(name: "Mock Project", duration: 3)

        // mock store 只验证 ProjectStoring 合约，不提前引入文件系统持久化。
        try await store.save(project)
        let projects = try await store.recentProjects()

        #expect(projects == [project])
    }
}
