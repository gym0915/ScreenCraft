import Foundation

// 视觉参数独立成模型，后续导出渲染器和编辑器预览可以共享同一套样式。
struct ProjectShadow: Codable, Equatable {
    var radius: Double
    var opacity: Double
    var yOffset: Double

    init(radius: Double = 24, opacity: Double = 0.28, yOffset: Double = 16) {
        self.radius = radius
        self.opacity = opacity
        self.yOffset = yOffset
    }
}

// ProjectStyle 存储项目级展示风格，不依赖 SwiftUI 类型，便于序列化和导出复用。
struct ProjectStyle: Codable, Equatable {
    var background: String
    var padding: Double
    var cornerRadius: Double
    var shadow: ProjectShadow
    var cursorScale: Double

    // default 代表新建项目的初始风格，测试会锁定这些基础参数。
    static let `default` = ProjectStyle()

    init(
        background: String = "#101014",
        padding: Double = 48,
        cornerRadius: Double = 24,
        shadow: ProjectShadow = ProjectShadow(),
        cursorScale: Double = 1
    ) {
        self.background = background
        self.padding = padding
        self.cornerRadius = cornerRadius
        self.shadow = shadow
        self.cursorScale = cursorScale
    }
}
