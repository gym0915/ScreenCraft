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
    func status(for type: PermissionType) async -> PermissionStatus {
        switch type {
        case .screenRecording:
            return CGPreflightScreenCaptureAccess() ? .granted : .denied
        case .microphone, .accessibility, .inputMonitoring:
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
        case .microphone, .accessibility, .inputMonitoring:
            return .unknown
        case .camera:
            return .unsupported
        }
    }
}
