import Foundation

// ProjectMedia 使用可选 URL 表示各轨道是否已采集，避免基础项目强依赖所有媒体类型。
struct ProjectMedia: Codable, Equatable {
    var screenVideoURL: URL?
    var microphoneAudioURL: URL?
    // camera 只作为后续能力预留，当前 UI 不提供摄像头录制入口。
    var cameraVideoURL: URL?
    var screenVideoPath: String?
    var microphoneAudioPath: String?
    var mouseEventsPath: String?

    init(
        screenVideoURL: URL? = nil,
        microphoneAudioURL: URL? = nil,
        cameraVideoURL: URL? = nil,
        screenVideoPath: String? = nil,
        microphoneAudioPath: String? = nil,
        mouseEventsPath: String? = nil
    ) {
        self.screenVideoURL = screenVideoURL
        self.microphoneAudioURL = microphoneAudioURL
        self.cameraVideoURL = cameraVideoURL
        self.screenVideoPath = screenVideoPath
        self.microphoneAudioPath = microphoneAudioPath
        self.mouseEventsPath = mouseEventsPath
    }
}

enum RecordingSourceKind: String, Codable, Equatable {
    case display
    case window
    case region
}

struct RecordingSourceMetadata: Codable, Equatable {
    let id: String
    let kind: RecordingSourceKind
    let title: String
    let appName: String?
    let geometry: CaptureSourceGeometry?
    let captureResolution: CaptureResolution?

    init(
        id: String,
        kind: RecordingSourceKind,
        title: String,
        appName: String?,
        geometry: CaptureSourceGeometry?,
        captureResolution: CaptureResolution?
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.appName = appName
        self.geometry = geometry
        self.captureResolution = captureResolution
    }

    init(source: ScreenCaptureSource) {
        self.init(
            id: source.id,
            kind: RecordingSourceKind(sourceKind: source.kind),
            title: source.title,
            appName: source.appName,
            geometry: source.geometry,
            captureResolution: source.captureResolution
        )
    }
}

private extension RecordingSourceKind {
    init(sourceKind: ScreenCaptureSource.Kind) {
        switch sourceKind {
        case .display:
            self = .display
        case .window:
            self = .window
        case .region:
            self = .region
        }
    }
}

// RecordingProject 是项目持久化的聚合根，后续 ProjectStore 只需要读写这一层模型。
struct RecordingProject: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var createdAt: Date
    var media: ProjectMedia
    var source: RecordingSourceMetadata?
    var timeline: Timeline

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        media: ProjectMedia = ProjectMedia(),
        source: RecordingSourceMetadata? = nil,
        timeline: Timeline
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.media = media
        self.source = source
        self.timeline = timeline
    }

    // 便捷初始化用于基础测试和 Spike 录制结果，避免调用方手动构造 Timeline。
    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        media: ProjectMedia = ProjectMedia(),
        source: RecordingSourceMetadata? = nil,
        duration: TimeInterval = 0
    ) {
        self.init(
            id: id,
            name: name,
            createdAt: createdAt,
            media: media,
            source: source,
            timeline: Timeline(duration: duration)
        )
    }
}
