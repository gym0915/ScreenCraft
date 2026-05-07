import Combine
import Foundation

struct HomePermissionRow: Identifiable, Equatable {
    let type: PermissionType
    let title: String
    let status: PermissionStatus
    let statusText: String
    let isReserved: Bool

    var id: PermissionType { type }
}

@MainActor
final class HomeViewModel: ObservableObject {
    // 暴露 environment 便于当前基础测试确认依赖注入路径，后续可收敛为私有属性。
    let environment: AppEnvironment

    // 该状态用于标记基础脚手架已接通，不代表真实录制链路可用。
    @Published var foundationStatus = "Foundation Ready"
    @Published private(set) var permissionRows: [HomePermissionRow] = []
    @Published private(set) var captureSources: [ScreenCaptureSource] = []
    @Published var selectedCaptureSourceID: String?
    @Published private(set) var isRefreshingCaptureSources = false
    @Published private(set) var isRecordingWindow = false
    @Published private(set) var outputFilePath: String?
    @Published private(set) var spikeStatusMessage = "Ready to refresh windows."
    @Published private(set) var permissionHelpMessage: String?
    @Published private(set) var audioInputDevices: [AudioInputDevice] = []
    @Published var selectedAudioInputDeviceID: String?
    @Published private(set) var isRefreshingAudioInputDevices = false
    @Published private(set) var isRecordingMicrophone = false
    @Published private(set) var audioOutputFilePath: String?
    @Published private(set) var audioSpikeStatusMessage = "Ready to refresh microphones."
    @Published private(set) var audioPermissionHelpMessage: String?
    @Published private(set) var isRecordingMouseEvents = false
    @Published private(set) var mouseEventCount = 0
    @Published private(set) var mouseEventDebugLines: [String] = []
    @Published private(set) var mouseEventSpikeStatusMessage = "Ready to record mouse events."
    @Published private(set) var mouseEventPermissionHelpMessage: String?
    private var packageMouseEventSession: MouseEventRecordingSession?
    private var packageAudioSession: AudioRecordingSession?

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    var isWindowCaptureSpikeEnabled: Bool {
        true
    }

    var canStartWindowRecording: Bool {
        selectedCaptureSource != nil && !isRecordingWindow
    }

    var selectedCaptureSourceKindLabel: String {
        switch selectedCaptureSource?.kind {
        case .display:
            return "Display"
        case .window:
            return "Window"
        case .region:
            return "Region"
        case nil:
            return "None"
        }
    }

    var selectedCaptureResolutionLabel: String {
        selectedCaptureSource?.captureResolutionLabel ?? "Unknown"
    }

    var selectedCaptureQualityWarningMessage: String? {
        selectedCaptureSource?.qualityWarning?.message
    }

    var canStopWindowRecording: Bool {
        isRecordingWindow
    }

    var canStartMicrophoneRecording: Bool {
        selectedAudioInputDeviceID != nil && !isRecordingMicrophone
    }

    var canStopMicrophoneRecording: Bool {
        isRecordingMicrophone
    }

    var canStartMouseEventRecording: Bool {
        !isRecordingMouseEvents
    }

    var canStopMouseEventRecording: Bool {
        isRecordingMouseEvents
    }

    func loadFoundationState() async {
        // Home 只查询基础权限状态，不调用 request，避免 mock UI 阶段出现系统权限弹窗。
        var rows: [HomePermissionRow] = []

        for type in PermissionType.allCases {
            let status = await environment.permissionManager.status(for: type)

            rows.append(HomePermissionRow(
                type: type,
                title: type.displayName,
                status: status,
                statusText: statusText(for: type, status: status),
                isReserved: type == .camera
            ))
        }

        permissionRows = rows
    }

    private func statusText(for type: PermissionType, status: PermissionStatus) -> String {
        // camera 当前只作为数据模型预留，UI 文案要明确它不是可请求权限。
        guard type != .camera else {
            return "Reserved for later"
        }

        switch status {
        case .unknown:
            return "Unknown"
        case .notDetermined:
            return "Not Determined"
        case .granted:
            return "Granted"
        case .denied:
            return "Denied"
        case .unsupported:
            return "Unsupported"
        }
    }

    func refreshCaptureSources() async throws {
        isRefreshingCaptureSources = true
        defer { isRefreshingCaptureSources = false }

        do {
            let sources = try await environment.screenCaptureService.availableSources()
            captureSources = sources

            if selectedCaptureSourceID == nil || !sources.contains(where: { $0.id == selectedCaptureSourceID }) {
                selectedCaptureSourceID = sources.first(where: { $0.kind == .window })?.id
            }

            permissionHelpMessage = nil
            spikeStatusMessage = sources.isEmpty ? "No windows found." : "Found \(sources.count) capture sources."
        } catch {
            let message = error.localizedDescription
            permissionHelpMessage = Self.screenRecordingPermissionHelp
            spikeStatusMessage = message
            throw error
        }
    }

    func startSelectedWindowRecording() async throws {
        guard let selectedCaptureSource else {
            spikeStatusMessage = "Select a window before recording."
            throw ScreenCaptureServiceError.sourceUnavailable
        }

        let configuration = ScreenRecordingConfiguration(
            source: selectedCaptureSource,
            outputDirectory: Self.defaultSpikeOutputDirectory
        )

        do {
            try await environment.screenCaptureService.startRecording(configuration: configuration)
            packageMouseEventSession = try? await environment.mouseEventService.startRecording(
                captureRegion: Self.mouseEventCaptureRegion(for: selectedCaptureSource)
            )
            if selectedAudioInputDeviceID != nil {
                packageAudioSession = try? await environment.audioInputService.startRecording(
                    deviceID: selectedAudioInputDeviceID,
                    outputDirectory: configuration.packageDirectory.appendingPathComponent("media", isDirectory: true)
                )
            }
            isRecordingWindow = true
            outputFilePath = nil
            permissionHelpMessage = nil
            spikeStatusMessage = "Recording \(selectedCaptureSource.displayLabel)."
        } catch {
            spikeStatusMessage = error.localizedDescription
            throw error
        }
    }

    func stopWindowRecording() async throws {
        do {
            let project = try await environment.screenCaptureService.stopRecording()
            let mouseEvents = try await stopPackageMouseEventRecordingIfNeeded()
            let microphoneAudioURL = try await stopPackageAudioRecordingIfNeeded()
            var packageProject = project
            packageProject.media.mouseEventsPath = "events/mouse-events.json"
            if let microphoneAudioURL {
                packageProject.media.microphoneAudioURL = microphoneAudioURL
                packageProject.media.microphoneAudioPath = "media/microphone.m4a"
            }

            try await environment.projectStore.save(packageProject, mouseEvents: mouseEvents)
            if let zoomAnalysisConfiguration = Self.zoomAnalysisConfiguration(for: packageProject) {
                packageProject = try await environment.projectStore.analyzeZoomSegments(
                    for: packageProject,
                    configuration: zoomAnalysisConfiguration
                )
            }

            isRecordingWindow = false
            outputFilePath = packageProject.media.screenVideoURL?.path
            spikeStatusMessage = outputFilePath.map { "Saved recording to \($0)" } ?? "Recording stopped."
        } catch {
            spikeStatusMessage = error.localizedDescription
            throw error
        }
    }

    func refreshAudioInputDevices() async throws {
        isRefreshingAudioInputDevices = true
        defer { isRefreshingAudioInputDevices = false }

        do {
            let devices = try await environment.audioInputService.availableInputDevices()
            audioInputDevices = devices

            if selectedAudioInputDeviceID == nil || !devices.contains(where: { $0.id == selectedAudioInputDeviceID }) {
                selectedAudioInputDeviceID = devices.first(where: \.isDefault)?.id ?? devices.first?.id
            }

            audioPermissionHelpMessage = nil
            audioSpikeStatusMessage = devices.isEmpty ? "No microphones found." : "Found \(devices.count) microphones."
        } catch {
            handleAudioSpikeError(error)
            throw error
        }
    }

    func startMicrophoneRecording() async throws {
        guard selectedAudioInputDeviceID != nil else {
            audioSpikeStatusMessage = "Select a microphone before recording."
            throw AudioInputServiceError.deviceUnavailable
        }

        do {
            let session = try await environment.audioInputService.startRecording(
                deviceID: selectedAudioInputDeviceID,
                outputDirectory: Self.defaultAudioSpikeOutputDirectory
            )
            isRecordingMicrophone = true
            audioOutputFilePath = nil
            audioPermissionHelpMessage = nil
            audioSpikeStatusMessage = "Recording microphone to \(session.outputURL.path)."
        } catch {
            handleAudioSpikeError(error)
            throw error
        }
    }

    func stopMicrophoneRecording() async throws {
        do {
            let result = try await environment.audioInputService.stopRecording()
            isRecordingMicrophone = false
            audioOutputFilePath = result.session.outputURL.path
            audioSpikeStatusMessage = "Saved microphone recording to \(result.session.outputURL.path)."
        } catch {
            handleAudioSpikeError(error)
            throw error
        }
    }

    func startMouseEventRecording() async throws {
        do {
            let captureRegion = environment.mouseEventCaptureRegion()
            let session = try await environment.mouseEventService.startRecording(
                captureRegion: captureRegion
            )
            isRecordingMouseEvents = true
            mouseEventCount = 0
            mouseEventDebugLines = []
            mouseEventPermissionHelpMessage = nil
            mouseEventSpikeStatusMessage = "Recording mouse events in region \(Self.regionSummary(session.captureRegion))."
        } catch {
            handleMouseEventSpikeError(error)
            throw error
        }
    }

    func stopMouseEventRecording() async throws {
        do {
            let result = try await environment.mouseEventService.stopRecording()
            isRecordingMouseEvents = false
            mouseEventCount = result.events.count
            mouseEventDebugLines = result.events.map(Self.debugLine(for:))
            mouseEventSpikeStatusMessage = "Recorded \(result.events.count) mouse events."
        } catch {
            handleMouseEventSpikeError(error)
            throw error
        }
    }

    private var selectedCaptureSource: ScreenCaptureSource? {
        captureSources.first { $0.id == selectedCaptureSourceID }
    }

    private func handleAudioSpikeError(_ error: Error) {
        if case AudioInputServiceError.permissionDenied = error {
            audioPermissionHelpMessage = SystemPermissionManager.microphonePermissionHelp
        }

        audioSpikeStatusMessage = error.localizedDescription
    }

    private func handleMouseEventSpikeError(_ error: Error) {
        if case MouseEventServiceError.permissionDenied = error {
            mouseEventPermissionHelpMessage = Self.mouseEventPermissionHelp
        }

        mouseEventSpikeStatusMessage = error.localizedDescription
    }

    private static func debugLine(for event: MouseEvent) -> String {
        let recordingSummary = event.recordingLocation.map {
            String(format: "recording=(%.1f, %.1f)", $0.x, $0.y)
        } ?? "recording=outside"

        return String(
            format: "%@ t=%.2f global=(%.1f, %.1f) %@",
            event.kind.rawValue,
            event.timestamp,
            event.globalLocation.x,
            event.globalLocation.y,
            recordingSummary
        )
    }

    private static func regionSummary(_ region: MouseEventCaptureRegion) -> String {
        String(
            format: "origin=(%.1f, %.1f), size=(%.1f, %.1f), scale=%.1f",
            region.origin.x,
            region.origin.y,
            region.size.width,
            region.size.height,
            region.backingScaleFactor
        )
    }

    private func stopPackageMouseEventRecordingIfNeeded() async throws -> [MouseEvent] {
        guard packageMouseEventSession != nil else {
            return await environment.mouseEventService.recordedEvents()
        }

        packageMouseEventSession = nil
        let result = try await environment.mouseEventService.stopRecording()
        mouseEventCount = result.events.count
        mouseEventDebugLines = result.events.map(Self.debugLine(for:))
        return result.events
    }

    private func stopPackageAudioRecordingIfNeeded() async throws -> URL? {
        guard let packageAudioSession else {
            return nil
        }

        self.packageAudioSession = nil
        let result = try await environment.audioInputService.stopRecording()
        let microphoneURL = packageAudioSession.outputURL
            .deletingLastPathComponent()
            .appendingPathComponent("microphone.m4a")

        if FileManager.default.fileExists(atPath: result.session.outputURL.path) {
            if FileManager.default.fileExists(atPath: microphoneURL.path) {
                try FileManager.default.removeItem(at: microphoneURL)
            }
            try FileManager.default.moveItem(at: result.session.outputURL, to: microphoneURL)
        }

        return microphoneURL
    }

    private static func mouseEventCaptureRegion(for source: ScreenCaptureSource) -> MouseEventCaptureRegion {
        guard let geometry = source.geometry else {
            return .mainDisplay()
        }

        return MouseEventCaptureRegion(
            origin: MouseEventLocation(x: geometry.originX, y: geometry.originY),
            size: MouseEventSize(width: geometry.width, height: geometry.height),
            backingScaleFactor: geometry.scale
        )
    }

    private static func zoomAnalysisConfiguration(for project: RecordingProject) -> ZoomAnalysisConfiguration? {
        guard let captureResolution = project.source?.captureResolution else {
            return nil
        }

        return ZoomAnalysisConfiguration(
            recordingSize: MouseEventSize(
                width: Double(captureResolution.width),
                height: Double(captureResolution.height)
            )
        )
    }

    static let screenRecordingPermissionHelp = "System Settings -> Privacy & Security -> Screen & System Audio Recording"
    static let screenRecordingPermissionURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
    )!
    static let mouseEventPermissionHelp = "System Settings -> Privacy & Security -> Input Monitoring or Accessibility"
    static let inputMonitoringPermissionURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
    )!

    private static let defaultSpikeOutputDirectory = AppEnvironment.recordingPackageRootDirectory

    private static let defaultAudioSpikeOutputDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ScreenCraft", isDirectory: true)
        .appendingPathComponent("AudioSpike", isDirectory: true)
}
