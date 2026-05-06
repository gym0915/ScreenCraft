import AVFoundation
import CoreGraphics

protocol PermissionManaging {
    // 权限查询和请求都保持 async，以匹配后续系统弹窗或设置跳转后的异步结果。
    func status(for type: PermissionType) async -> PermissionStatus
    func request(_ type: PermissionType) async -> PermissionStatus
}

struct MockPermissionManager: PermissionManaging {
    func status(for type: PermissionType) async -> PermissionStatus {
        // camera 在当前产品范围中预留但不启用，mock 明确标记为 unsupported。
        type == .camera ? .unsupported : .unknown
    }

    func request(_ type: PermissionType) async -> PermissionStatus {
        // mock request 不触发系统弹窗，只模拟非 camera 权限最终可被授权。
        type == .camera ? .unsupported : .granted
    }
}

struct SystemPermissionManager: PermissionManaging {
    static let microphonePermissionHelp = "System Settings -> Privacy & Security -> Microphone"
    static let microphonePermissionURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone"
    )!

    func status(for type: PermissionType) async -> PermissionStatus {
        switch type {
        case .screenRecording:
            return CGPreflightScreenCaptureAccess() ? .granted : .denied
        case .microphone:
            switch AVCaptureDevice.authorizationStatus(for: .audio) {
            case .authorized:
                return .granted
            case .notDetermined:
                return .notDetermined
            case .denied, .restricted:
                return .denied
            @unknown default:
                return .unknown
            }
        case .accessibility, .inputMonitoring:
            return .unknown
        case .camera:
            // camera 不进入本次 MVP/Spike UI，真实环境也保持 unsupported。
            return .unsupported
        }
    }

    func request(_ type: PermissionType) async -> PermissionStatus {
        switch type {
        case .screenRecording:
            return CGRequestScreenCaptureAccess() ? .granted : .denied
        case .microphone:
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            return granted ? .granted : .denied
        case .accessibility, .inputMonitoring:
            return .unknown
        case .camera:
            return .unsupported
        }
    }
}
