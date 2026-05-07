import Foundation

protocol ScreenCaptureServicing {
    // 协议先保持最小状态查询边界，避免基础脚手架阶段提前绑定 ScreenCaptureKit。
    func recordingState() async -> ScreenRecordingState
    func availableSources() async throws -> [ScreenCaptureSource]
    func startRecording(configuration: ScreenRecordingConfiguration) async throws
    func stopRecording() async throws -> RecordingProject
}

enum ScreenCaptureServiceError: LocalizedError, Equatable {
    case sourceUnavailable
    case alreadyRecording
    case notRecording
    case permissionDenied(String)
    case recordingFailed(String)

    var errorDescription: String? {
        switch self {
        case .sourceUnavailable:
            return "Selected capture source is no longer available."
        case .alreadyRecording:
            return "A window recording is already in progress."
        case .notRecording:
            return "No window recording is currently in progress."
        case .permissionDenied(let message):
            return message
        case .recordingFailed(let message):
            return message
        }
    }
}

@MainActor
final class MockScreenCaptureService: ScreenCaptureServicing {
    private var state: ScreenRecordingState = .idle
    private var activeConfiguration: ScreenRecordingConfiguration?

    func recordingState() async -> ScreenRecordingState {
        // mock 不触发屏幕录制权限；它只证明依赖注入路径可编译、可测试。
        state
    }

    func availableSources() async throws -> [ScreenCaptureSource] {
        // mock source 只服务 UI 状态机测试，不对应任何真实窗口。
        [
            ScreenCaptureSource(
                id: "mock-display",
                kind: .display,
                title: "Mock Display",
                appName: nil,
                geometry: CaptureSourceGeometry(
                    originX: 0,
                    originY: 0,
                    width: 1512,
                    height: 982,
                    scale: 2
                )
            ),
            ScreenCaptureSource(
                id: "mock-window",
                kind: .window,
                title: "Mock Window",
                appName: "ScreenCraft",
                geometry: CaptureSourceGeometry(
                    originX: 80,
                    originY: 120,
                    width: 320,
                    height: 240,
                    scale: 1
                )
            ),
            ScreenCaptureSource(
                id: "mock-region",
                kind: .region,
                title: "Mock Region",
                appName: nil,
                geometry: CaptureSourceGeometry(
                    originX: 100,
                    originY: 100,
                    width: 960,
                    height: 540,
                    scale: 2
                )
            )
        ]
    }

    func startRecording(configuration: ScreenRecordingConfiguration) async throws {
        guard state != .recording else {
            throw ScreenCaptureServiceError.alreadyRecording
        }

        activeConfiguration = configuration
        state = .recording
    }

    func stopRecording() async throws -> RecordingProject {
        guard state == .recording, let activeConfiguration else {
            throw ScreenCaptureServiceError.notRecording
        }

        let outputURL = activeConfiguration.screenVideoFileURL(createdAt: Date(timeIntervalSince1970: 0))
        self.activeConfiguration = nil
        state = .idle

        return RecordingProject(
            name: "Capture Configuration Recording",
            media: ProjectMedia(
                screenVideoURL: outputURL,
                screenVideoPath: ScreenRecordingConfiguration.screenVideoRelativePath
            ),
            duration: 0
        )
    }
}
