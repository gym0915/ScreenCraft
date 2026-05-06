protocol AudioInputServicing {
    // 保持 async 形状，以便后续真实设备枚举实现不改变调用方接口。
    func availableInputDevices() async -> [AudioInputDevice]
}

struct MockAudioInputService: AudioInputServicing {
    func availableInputDevices() async -> [AudioInputDevice] {
        // 使用稳定占位设备，测试和 Home UI 不依赖当前机器的真实麦克风配置。
        [
            AudioInputDevice(
                id: "mock-microphone",
                name: "Mock Microphone",
                isDefault: true
            )
        ]
    }
}
