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

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    var isWindowCaptureSpikeEnabled: Bool {
        true
    }

    var canStartWindowRecording: Bool {
        selectedCaptureSource?.kind == .window && !isRecordingWindow
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
            isRecordingWindow = false
            outputFilePath = project.media.screenVideoURL?.path
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

    private var selectedCaptureSource: ScreenCaptureSource? {
        captureSources.first { $0.id == selectedCaptureSourceID }
    }

    private func handleAudioSpikeError(_ error: Error) {
        if case AudioInputServiceError.permissionDenied = error {
            audioPermissionHelpMessage = SystemPermissionManager.microphonePermissionHelp
        }

        audioSpikeStatusMessage = error.localizedDescription
    }

    static let screenRecordingPermissionHelp = "System Settings -> Privacy & Security -> Screen & System Audio Recording"
    static let screenRecordingPermissionURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture"
    )!

    private static let defaultSpikeOutputDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ScreenCraft", isDirectory: true)
        .appendingPathComponent("WindowCaptureSpike", isDirectory: true)

    private static let defaultAudioSpikeOutputDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("ScreenCraft", isDirectory: true)
        .appendingPathComponent("AudioSpike", isDirectory: true)
}
