import Combine
import Foundation

@MainActor
final class AppEnvironment: ObservableObject {
    // AppEnvironment 是 SwiftUI 层唯一接触服务依赖的入口，避免 View 直接创建系统服务。
    let permissionManager: PermissionManaging
    let screenCaptureService: ScreenCaptureServicing
    let audioInputService: AudioInputServicing
    let mouseEventService: MouseEventServicing
    let projectStore: ProjectStoring

    init(
        permissionManager: PermissionManaging,
        screenCaptureService: ScreenCaptureServicing,
        audioInputService: AudioInputServicing,
        mouseEventService: MouseEventServicing,
        projectStore: ProjectStoring
    ) {
        self.permissionManager = permissionManager
        self.screenCaptureService = screenCaptureService
        self.audioInputService = audioInputService
        self.mouseEventService = mouseEventService
        self.projectStore = projectStore
    }

    // 基础脚手架阶段只注入 mock，确保启动 App 不触发系统权限弹窗或真实硬件访问。
    static let mock = AppEnvironment(
        permissionManager: MockPermissionManager(),
        screenCaptureService: MockScreenCaptureService(),
        audioInputService: MockAudioInputService(),
        mouseEventService: MockMouseEventService(),
        projectStore: MockProjectStore()
    )

    // Spike 环境接入真实屏幕和麦克风服务；鼠标事件和项目持久化仍保持 mock，避免扩大验证范围。
    static let spike = AppEnvironment(
        permissionManager: SystemPermissionManager(),
        screenCaptureService: ScreenCaptureKitScreenCaptureService(),
        audioInputService: AVFoundationAudioInputService(),
        mouseEventService: MockMouseEventService(),
        projectStore: MockProjectStore()
    )
}
