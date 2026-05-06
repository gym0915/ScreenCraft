import Testing
@testable import ScreenCraft

@MainActor
struct AppEnvironmentTests {
    @Test func mockEnvironmentCanBeInjectedIntoHomeViewModel() {
        // 基础脚手架必须先证明 AppEnvironment 能被 HomeViewModel 接收并保持引用语义。
        let environment = AppEnvironment.mock
        let viewModel = HomeViewModel(environment: environment)

        #expect(viewModel.environment === environment)
        #expect(viewModel.foundationStatus == "Foundation Ready")
    }

    @Test func mockEnvironmentProvidesSafePlaceholderServices() async throws {
        let environment = AppEnvironment.mock

        // 通过统一环境入口验证 mock，不让 App 启动时触发真实权限、硬件或文件系统访问。
        let screenRecordingStatus = await environment.permissionManager.status(for: .screenRecording)
        let cameraStatus = await environment.permissionManager.status(for: .camera)
        let recordingState = await environment.screenCaptureService.recordingState()
        let audioDevices = await environment.audioInputService.availableInputDevices()
        let mouseEvents = await environment.mouseEventService.recordedEvents()
        let projects = try await environment.projectStore.recentProjects()

        #expect(screenRecordingStatus == .unknown)
        #expect(cameraStatus == .unsupported)
        #expect(recordingState == .idle)
        #expect(audioDevices == [AudioInputDevice(id: "mock-microphone", name: "Mock Microphone", isDefault: true)])
        #expect(mouseEvents.isEmpty)
        #expect(projects.isEmpty)
    }
}
