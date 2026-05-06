import Foundation

// MouseEvent 保存时间线需要的鼠标事件摘要，不直接依赖 NSEvent，方便测试和序列化。
struct MouseEvent: Identifiable, Codable, Equatable {
    let id: UUID
    let kind: MouseEventKind
    let timestamp: TimeInterval
    let location: MouseEventLocation

    init(
        id: UUID = UUID(),
        kind: MouseEventKind,
        timestamp: TimeInterval,
        location: MouseEventLocation
    ) {
        self.id = id
        self.kind = kind
        self.timestamp = timestamp
        self.location = location
    }
}

// 事件类型先覆盖时间线展示需要的最小集合，真实监听策略留到输入事件阶段实现。
enum MouseEventKind: String, Codable, Equatable {
    case move
    case leftClick
    case rightClick

    // drag 先作为时间线数据能力保留；基础脚手架阶段不会监听真实输入事件。
    case drag
}

// 使用 Double 坐标而不是 AppKit 类型，保持模型层和平台 UI 解耦。
struct MouseEventLocation: Codable, Equatable {
    let x: Double
    let y: Double
}
