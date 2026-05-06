enum PermissionStatus: String, Codable, Equatable {
    // unknown 用于 mock 或尚未查询系统 API 的阶段，避免把未知状态误判为拒绝。
    case unknown
    case notDetermined
    case granted
    case denied

    // unsupported 表示当前阶段或当前平台不应请求该权限。
    case unsupported
}
