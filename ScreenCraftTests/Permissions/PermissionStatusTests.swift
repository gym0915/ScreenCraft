import Testing
@testable import ScreenCraft

struct PermissionStatusTests {
    @Test func permissionTypesExposeUserFacingDisplayNames() {
        // 权限名称会直接显示在 Home UI 中，测试防止后续重命名破坏用户可读性。
        #expect(PermissionType.screenRecording.displayName == "Screen Recording")
        #expect(PermissionType.microphone.displayName == "Microphone")
        #expect(PermissionType.accessibility.displayName == "Accessibility")
        #expect(PermissionType.inputMonitoring.displayName == "Input Monitoring")
        #expect(PermissionType.camera.displayName == "Camera")
    }

    @Test func mockPermissionManagerTreatsCameraAsUnsupported() async {
        let manager = MockPermissionManager()

        // camera 目前只作为预留能力，mock 查询和请求都必须保持 unsupported。
        let status = await manager.status(for: .camera)
        let requestResult = await manager.request(.camera)

        #expect(status == .unsupported)
        #expect(requestResult == .unsupported)
    }
}
