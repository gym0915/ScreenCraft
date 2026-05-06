import Testing
@testable import ScreenCraft

@MainActor
struct HomeViewModelTests {
    @Test func loadingFoundationStateBuildsPermissionRowsFromMockEnvironment() async {
        let viewModel = HomeViewModel(environment: .mock)

        // Home 只读取 mock 权限状态，不应触发任何真实系统权限请求。
        await viewModel.loadFoundationState()

        #expect(viewModel.permissionRows.map(\.title) == [
            "Screen Recording",
            "Microphone",
            "Accessibility",
            "Input Monitoring",
            "Camera"
        ])
        #expect(viewModel.permissionRows.map(\.statusText) == [
            "Unknown",
            "Unknown",
            "Unknown",
            "Unknown",
            "Reserved for later"
        ])
        #expect(viewModel.permissionRows.last?.isReserved == true)
        #expect(viewModel.isWindowCaptureSpikeEnabled == true)
    }

    @Test func spikeRecordingFlowRefreshesSourcesAndPublishesOutputPath() async throws {
        let viewModel = HomeViewModel(environment: .mock)

        try await viewModel.refreshCaptureSources()

        #expect(viewModel.captureSources.map(\.displayLabel) == ["ScreenCraft - Mock Window"])
        #expect(viewModel.selectedCaptureSourceID == "mock-window")
        #expect(viewModel.canStartWindowRecording == true)

        try await viewModel.startSelectedWindowRecording()

        #expect(viewModel.isRecordingWindow == true)
        #expect(viewModel.canStartWindowRecording == false)
        #expect(viewModel.canStopWindowRecording == true)

        try await viewModel.stopWindowRecording()

        #expect(viewModel.isRecordingWindow == false)
        #expect(viewModel.outputFilePath?.hasSuffix(".mov") == true)
        #expect(viewModel.canStopWindowRecording == false)
    }

    @Test func microphoneSpikeFlowRefreshesDevicesAndPublishesOutputPath() async throws {
        let viewModel = HomeViewModel(environment: .mock)

        try await viewModel.refreshAudioInputDevices()

        #expect(viewModel.audioInputDevices.map(\.name) == ["Mock Microphone"])
        #expect(viewModel.selectedAudioInputDeviceID == "mock-microphone")
        #expect(viewModel.canStartMicrophoneRecording == true)

        try await viewModel.startMicrophoneRecording()

        #expect(viewModel.isRecordingMicrophone == true)
        #expect(viewModel.canStartMicrophoneRecording == false)
        #expect(viewModel.canStopMicrophoneRecording == true)

        try await viewModel.stopMicrophoneRecording()

        #expect(viewModel.isRecordingMicrophone == false)
        #expect(viewModel.audioOutputFilePath?.hasSuffix(".m4a") == true)
        #expect(viewModel.canStopMicrophoneRecording == false)
    }
}
