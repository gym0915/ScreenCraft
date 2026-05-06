// ScreenCraftApp 负责创建应用入口和顶层依赖环境。

import SwiftUI

@main
struct ScreenCraftApp: App {
    // 环境对象在 App 生命周期内保持单例语义，后续真实服务也应从这里统一注入。
    @StateObject private var environment = AppEnvironment.spike

    var body: some Scene {
        WindowGroup {
            // 入口直接加载 Home，避免保留模板 ContentView 作为真实导航路径。
            HomeView(viewModel: HomeViewModel(environment: environment))
        }
    }
}
