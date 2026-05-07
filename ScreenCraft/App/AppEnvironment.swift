import Combine
import Foundation

@MainActor
final class AppEnvironment: ObservableObject {
    // AppEnvironment 是 SwiftUI 层唯一接触服务依赖的入口，避免 View 直接创建系统服务。
    let permissionManager: PermissionManaging
    let screenCaptureService: ScreenCaptureServicing
    let audioInputService: AudioInputServicing
    let mouseEventService: MouseEventServicing
    let mouseEventCaptureRegion: () -> MouseEventCaptureRegion
    let projectStore: ProjectStoring

    init(
        permissionManager: PermissionManaging,
        screenCaptureService: ScreenCaptureServicing,
        audioInputService: AudioInputServicing,
        mouseEventService: MouseEventServicing,
        mouseEventCaptureRegion: @escaping () -> MouseEventCaptureRegion,
        projectStore: ProjectStoring
    ) {
        self.permissionManager = permissionManager
        self.screenCaptureService = screenCaptureService
        self.audioInputService = audioInputService
        self.mouseEventService = mouseEventService
        self.mouseEventCaptureRegion = mouseEventCaptureRegion
        self.projectStore = projectStore
    }

    // 基础脚手架阶段只注入 mock，确保启动 App 不触发系统权限弹窗或真实硬件访问。
    static var mock: AppEnvironment {
        AppEnvironment(
            permissionManager: MockPermissionManager(),
            screenCaptureService: MockScreenCaptureService(),
            audioInputService: MockAudioInputService(),
            mouseEventService: MockMouseEventService(seedEvents: [
                MouseEvent(
                    kind: .leftClick,
                    timestamp: 3.5,
                    globalLocation: MouseEventLocation(x: 120, y: 230)
                )
            ]),
            mouseEventCaptureRegion: { .debugRetinaFixture },
            projectStore: MockProjectStore()
        )
    }

    // Spike 环境接入真实屏幕、麦克风、鼠标事件服务和本地项目包持久化。
    static let spike = AppEnvironment(
        permissionManager: SystemPermissionManager(),
        screenCaptureService: ScreenCaptureKitScreenCaptureService(),
        audioInputService: AVFoundationAudioInputService(),
        mouseEventService: CoreGraphicsEventTapMouseEventService(),
        mouseEventCaptureRegion: { .mainDisplay() },
        projectStore: FileSystemProjectStore(rootDirectory: recordingPackageRootDirectory)
    )

    static let recordingPackageRootDirectory = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("ScreenCraft", isDirectory: true)
        .appendingPathComponent("Recordings", isDirectory: true)
}
