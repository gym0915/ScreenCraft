// ScreenCraftUITestsLaunchTests 生成启动截图，作为早期 UI 基线。

import XCTest

final class ScreenCraftUITestsLaunchTests: XCTestCase {

    override class var runsForEachTargetApplicationUIConfiguration: Bool {
        true
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLaunch() throws {
        let app = XCUIApplication()
        app.launch()

        // 启动截图作为 UI 基线产物，后续 Home 页面成型后可用于人工比对。
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "Launch Screen"
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
