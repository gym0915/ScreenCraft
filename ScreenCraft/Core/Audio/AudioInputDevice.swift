// AudioInputDevice 是跨 UI 和真实音频服务的稳定设备摘要，不暴露 AVFoundation 类型。
struct AudioInputDevice: Identifiable, Codable, Equatable {
    let id: String
    let name: String
    let isDefault: Bool
}
