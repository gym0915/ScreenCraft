// ScreenCraftUITests 覆盖应用启动和基础 UI 性能 smoke test。

import XCTest

final class ScreenCraftUITests: XCTestCase {

    override func setUpWithError() throws {
        // UI 测试失败后立即停止，避免后续步骤在未知界面状态下继续执行。
        continueAfterFailure = false
    }

    override func tearDownWithError() throws {
        // 当前 UI 测试不创建外部资源，暂时不需要额外清理。
    }

    @MainActor
    func testExample() throws {
        // 先验证 App 可以启动到默认窗口，后续 Home UI 稳定后再增加具体断言。
        let app = XCUIApplication()
        app.launch()
    }

    @MainActor
    func testLaunchPerformance() throws {
        // 启动性能测试保留 Xcode 模板行为，用来观察基础脚手架是否引入明显启动回退。
        measure(metrics: [XCTApplicationLaunchMetric()]) {
            XCUIApplication().launch()
        }
    }
}
