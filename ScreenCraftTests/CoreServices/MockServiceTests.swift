import AVFoundation
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

    @Test func mockAudioInputServiceProvidesPlaceholderDevice() async throws {
        let service = MockAudioInputService()

        // 占位设备让服务边界可测试，同时不依赖开发机是否接入麦克风。
        let devices = try await service.availableInputDevices()

        #expect(devices == [AudioInputDevice(id: "mock-microphone", name: "Mock Microphone", isDefault: true)])
    }

    @Test func audioRecordingErrorsHaveReadableDescriptions() {
        #expect(AudioInputServiceError.alreadyRecording.localizedDescription == "A microphone recording is already in progress.")
        #expect(AudioInputServiceError.notRecording.localizedDescription == "No microphone recording is currently in progress.")
        #expect(AudioInputServiceError.deviceUnavailable.localizedDescription == "Selected microphone is no longer available.")
    }

    @Test func audioRecordingSessionAndResultAreEquatable() {
        let outputURL = URL(fileURLWithPath: "/tmp/microphone.m4a")
        let session = AudioRecordingSession(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            deviceID: "device-1",
            outputURL: outputURL,
            startedAt: Date(timeIntervalSince1970: 10)
        )
        let result = AudioRecordingResult(
            session: session,
            duration: 5,
            fileSizeBytes: 1024
        )

        #expect(AudioRecordingState.recording(session) == .recording(session))
        #expect(result.fileSizeBytes == 1024)
    }

    @Test func mockAudioServiceRecordsMicrophoneFile() async throws {
        let service = MockAudioInputService()
        let outputDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("ScreenCraftTests", isDirectory: true)

        let session = try await service.startRecording(
            deviceID: "mock-microphone",
            outputDirectory: outputDirectory
        )
        #expect(session.outputURL.pathExtension == "m4a")
        #expect(await service.recordingState() == .recording(session))

        let result = try await service.stopRecording()
        #expect(result.session == session)
        #expect(result.session.outputURL.pathExtension == "m4a")
        #expect(await service.recordingState() == .idle)
    }

    @Test func mockAudioServiceRejectsInvalidRecordingTransitions() async throws {
        let service = MockAudioInputService()
        let outputDirectory = FileManager.default.temporaryDirectory

        await #expect(throws: AudioInputServiceError.notRecording) {
            try await service.stopRecording()
        }

        _ = try await service.startRecording(
            deviceID: "mock-microphone",
            outputDirectory: outputDirectory
        )

        await #expect(throws: AudioInputServiceError.alreadyRecording) {
            try await service.startRecording(
                deviceID: "mock-microphone",
                outputDirectory: outputDirectory
            )
        }
    }

    @Test func avFoundationAudioRecorderSettingsUseM4AAACDefaults() {
        let settings = AVFoundationAudioInputService.defaultRecorderSettings

        #expect(settings[AVFormatIDKey] as? Int == Int(kAudioFormatMPEG4AAC))
        #expect(settings[AVSampleRateKey] as? Double == 48_000)
        #expect(settings[AVNumberOfChannelsKey] as? Int == 1)
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
