enum PermissionType: String, CaseIterable, Identifiable, Codable {
    // 列出最终产品会涉及的权限；camera 目前只作为预留能力，不在基础 UI 中请求。
    case screenRecording
    case microphone
    case accessibility
    case inputMonitoring
    case camera

    var id: String { rawValue }

    var displayName: String {
        // displayName 面向 UI 展示，保持与系统设置中的权限名称接近。
        switch self {
        case .screenRecording: "Screen Recording"
        case .microphone: "Microphone"
        case .accessibility: "Accessibility"
        case .inputMonitoring: "Input Monitoring"
        case .camera: "Camera"
        }
    }
}
