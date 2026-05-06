// ContentView 保留为模板兼容层，真实首页由 HomeView 承担。

import SwiftUI

// ContentView 仅保留给 Xcode 同步引用和预览使用；真实入口已经迁移到 HomeView。
struct ContentView: View {
    var body: some View {
        HomeView(viewModel: HomeViewModel(environment: .mock))
    }
}

#Preview {
    // 预览使用 mock 环境，避免 SwiftUI canvas 触发任何系统能力。
    ContentView()
}
