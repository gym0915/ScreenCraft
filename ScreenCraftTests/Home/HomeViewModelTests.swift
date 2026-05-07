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

        #expect(viewModel.captureSources.map(\.displayLabel) == [
            "Mock Display",
            "ScreenCraft - Mock Window",
            "Mock Region"
        ])
        #expect(viewModel.selectedCaptureSourceID == "mock-window")
        #expect(viewModel.canStartWindowRecording == true)
        #expect(viewModel.selectedCaptureSourceKindLabel == "Window")
        #expect(viewModel.selectedCaptureResolutionLabel == "320 x 240")
        #expect(viewModel.selectedCaptureQualityWarningMessage == "Capture source is 320 x 240. Enlarge the window before recording for a sharper 1080p export.")

        try await viewModel.startSelectedWindowRecording()

        #expect(viewModel.isRecordingWindow == true)
        #expect(viewModel.canStartWindowRecording == false)
        #expect(viewModel.canStopWindowRecording == true)

        try await viewModel.stopWindowRecording()

        #expect(viewModel.isRecordingWindow == false)
        #expect(viewModel.outputFilePath?.hasSuffix(".mov") == true)
        #expect(viewModel.canStopWindowRecording == false)
    }

    @Test func stoppingWindowRecordingSavesEditablePackageProject() async throws {
        let environment = AppEnvironment.mock
        let viewModel = HomeViewModel(environment: environment)

        try await viewModel.refreshCaptureSources()
        try await viewModel.startSelectedWindowRecording()
        try await viewModel.stopWindowRecording()

        let projects = try await environment.projectStore.recentProjects()
        let savedProject = try #require(projects.last)

        #expect(savedProject.media.screenVideoPath == "media/screen.mov")
        #expect(savedProject.media.mouseEventsPath == "events/mouse-events.json")
        #expect(savedProject.source?.id == "mock-window")
        #expect(savedProject.source?.kind == .window)
        #expect(savedProject.source?.captureResolution == CaptureResolution(width: 320, height: 240))
    }

    @Test func selectedMicrophoneIsSavedIntoWindowRecordingPackage() async throws {
        let environment = AppEnvironment.mock
        let viewModel = HomeViewModel(environment: environment)

        try await viewModel.refreshCaptureSources()
        try await viewModel.refreshAudioInputDevices()
        try await viewModel.startSelectedWindowRecording()
        try await viewModel.stopWindowRecording()

        let projects = try await environment.projectStore.recentProjects()
        let savedProject = try #require(projects.last)

        #expect(savedProject.media.microphoneAudioPath == "media/microphone.m4a")
    }

    @Test func captureConfigurationSummaryUpdatesWhenSelectingRegion() async throws {
        let viewModel = HomeViewModel(environment: .mock)

        try await viewModel.refreshCaptureSources()
        viewModel.selectedCaptureSourceID = "mock-region"

        #expect(viewModel.selectedCaptureSourceKindLabel == "Region")
        #expect(viewModel.selectedCaptureResolutionLabel == "1920 x 1080")
        #expect(viewModel.selectedCaptureQualityWarningMessage == nil)
        #expect(viewModel.canStartWindowRecording == true)
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

    @Test func mouseEventSpikeFlowPublishesMappedClickEvidence() async throws {
        let viewModel = HomeViewModel(environment: .mock)

        try await viewModel.startMouseEventRecording()

        #expect(viewModel.isRecordingMouseEvents == true)
        #expect(viewModel.canStartMouseEventRecording == false)
        #expect(viewModel.canStopMouseEventRecording == true)

        try await viewModel.stopMouseEventRecording()

        #expect(viewModel.isRecordingMouseEvents == false)
        #expect(viewModel.mouseEventCount == 1)
        #expect(viewModel.mouseEventDebugLines == [
            "leftClick t=3.50 global=(120.0, 230.0) recording=(40.0, 60.0)"
        ])
        #expect(viewModel.canStopMouseEventRecording == false)
    }
}
