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
    // 保持 async 形状，以便后续真实设备枚举实现不改变调用方接口。
    func availableInputDevices() async -> [AudioInputDevice]
}

struct MockAudioInputService: AudioInputServicing {
    func availableInputDevices() async -> [AudioInputDevice] {
        // 使用稳定占位设备，测试和 Home UI 不依赖当前机器的真实麦克风配置。
        [
            AudioInputDevice(
                id: "mock-microphone",
                name: "Mock Microphone",
                isDefault: true
            )
        ]
    }
}
