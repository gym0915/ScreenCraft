import Foundation

enum AudioRecordingState: Equatable {
    case idle
    case recording(AudioRecordingSession)
    case unavailable(String)
}

struct AudioRecordingSession: Equatable {
    let id: UUID
    let deviceID: String?
    let outputURL: URL
    let startedAt: Date
}

struct AudioRecordingResult: Equatable {
    let session: AudioRecordingSession
    let duration: TimeInterval
    let fileSizeBytes: Int64?
}

enum AudioInputServiceError: LocalizedError, Equatable {
    case permissionDenied(String)
    case deviceUnavailable
    case alreadyRecording
    case notRecording
    case recordingFailed(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied(let message):
            return message
        case .deviceUnavailable:
            return "Selected microphone is no longer available."
        case .alreadyRecording:
            return "A microphone recording is already in progress."
        case .notRecording:
            return "No microphone recording is currently in progress."
        case .recordingFailed(let message):
            return message
        }
    }
}

protocol AudioInputServicing {
    // 保持 async throws 形状，以便真实设备枚举、权限失败和硬件错误能沿同一服务边界返回。
    func recordingState() async -> AudioRecordingState
    func availableInputDevices() async throws -> [AudioInputDevice]
    func startRecording(deviceID: String?, outputDirectory: URL) async throws -> AudioRecordingSession
    func stopRecording() async throws -> AudioRecordingResult
}

@MainActor
final class MockAudioInputService: AudioInputServicing {
    private var state: AudioRecordingState = .idle
    private var activeSession: AudioRecordingSession?

    func recordingState() async -> AudioRecordingState {
        state
    }

    func availableInputDevices() async throws -> [AudioInputDevice] {
        // 使用稳定占位设备，测试和 Home UI 不依赖当前机器的真实麦克风配置。
        [
            AudioInputDevice(
                id: "mock-microphone",
                name: "Mock Microphone",
                isDefault: true
            )
        ]
    }

    func startRecording(
        deviceID: String?,
        outputDirectory: URL
    ) async throws -> AudioRecordingSession {
        guard case .idle = state else {
            throw AudioInputServiceError.alreadyRecording
        }

        let session = AudioRecordingSession(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
            deviceID: deviceID,
            outputURL: outputDirectory.appendingPathComponent("microphone-mock.m4a"),
            startedAt: Date(timeIntervalSince1970: 0)
        )
        activeSession = session
        state = .recording(session)
        return session
    }

    func stopRecording() async throws -> AudioRecordingResult {
        guard let activeSession else {
            throw AudioInputServiceError.notRecording
        }

        self.activeSession = nil
        state = .idle

        return AudioRecordingResult(
            session: activeSession,
            duration: 0,
            fileSizeBytes: 0
        )
    }
}
