protocol MouseEventServicing {
    // 鼠标事件采集会依赖辅助功能/输入监听权限，因此先只暴露可替换的读取边界。
    func recordedEvents() async -> [MouseEvent]
}

struct MockMouseEventService: MouseEventServicing {
    func recordedEvents() async -> [MouseEvent] {
        // mock 必须保持无事件，避免基础 UI 暗示已经开启了真实输入监听。
        []
    }
}
