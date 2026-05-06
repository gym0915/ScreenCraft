import Foundation

// ProjectMedia 使用可选 URL 表示各轨道是否已采集，避免基础项目强依赖所有媒体类型。
struct ProjectMedia: Codable, Equatable {
    var screenVideoURL: URL?
    var microphoneAudioURL: URL?
    // camera 只作为后续能力预留，当前 UI 不提供摄像头录制入口。
    var cameraVideoURL: URL?

    init(
        screenVideoURL: URL? = nil,
        microphoneAudioURL: URL? = nil,
        cameraVideoURL: URL? = nil
    ) {
        self.screenVideoURL = screenVideoURL
        self.microphoneAudioURL = microphoneAudioURL
        self.cameraVideoURL = cameraVideoURL
    }
}

// RecordingProject 是项目持久化的聚合根，后续 ProjectStore 只需要读写这一层模型。
struct RecordingProject: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var createdAt: Date
    var media: ProjectMedia
    var timeline: Timeline

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        media: ProjectMedia = ProjectMedia(),
        timeline: Timeline
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.media = media
        self.timeline = timeline
    }

    // 便捷初始化用于基础测试和 Spike 录制结果，避免调用方手动构造 Timeline。
    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        media: ProjectMedia = ProjectMedia(),
        duration: TimeInterval = 0
    ) {
        self.init(
            id: id,
            name: name,
            createdAt: createdAt,
            media: media,
            timeline: Timeline(duration: duration)
        )
    }
}
