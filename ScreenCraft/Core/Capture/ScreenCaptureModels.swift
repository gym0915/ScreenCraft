import Foundation

struct CaptureResolution: Codable, Equatable {
    let width: Int
    let height: Int

    var label: String {
        "\(width) x \(height)"
    }
}

struct CaptureSourceGeometry: Codable, Equatable {
    let originX: Double
    let originY: Double
    let width: Double
    let height: Double
    let scale: Double

    var captureResolution: CaptureResolution {
        let safeScale = max(scale, 1)

        return CaptureResolution(
            width: max(2, Int((width * safeScale).rounded())),
            height: max(2, Int((height * safeScale).rounded()))
        )
    }

    static func windowGeometry(
        windowFrame: CaptureSourceGeometry,
        filterContentRect: CaptureSourceGeometry
    ) -> CaptureSourceGeometry {
        let frameArea = windowFrame.width * windowFrame.height
        let contentArea = filterContentRect.width * filterContentRect.height

        return contentArea > frameArea ? filterContentRect : windowFrame
    }
}

enum CaptureQualityWarning: Equatable {
    case sourceTooSmall(actual: CaptureResolution, minimum: CaptureResolution)

    var message: String {
        switch self {
        case .sourceTooSmall(let actual, _):
            return "Capture source is \(actual.label). Enlarge the window before recording for a sharper 1080p export."
        }
    }
}

// ScreenRecordingState 先描述录制服务的粗粒度状态，后续 Spike 可在不改 UI 的情况下扩展实现。
enum ScreenRecordingState: Equatable {
    case idle
    case recording

    // 保留可读原因，后续真实采集服务可以把权限或系统 API 失败直接传到 UI 层。
    case unavailable(String)
}

struct ScreenCaptureSource: Identifiable, Equatable {
    enum Kind: Equatable {
        case display
        case window
        case region
    }

    let id: String
    let kind: Kind
    let title: String
    let appName: String?
    let geometry: CaptureSourceGeometry?

    init(
        id: String,
        kind: Kind,
        title: String,
        appName: String?,
        geometry: CaptureSourceGeometry? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.appName = appName
        self.geometry = geometry
    }

    var displayLabel: String {
        guard let appName, !appName.isEmpty else {
            return title
        }

        return "\(appName) - \(title)"
    }

    var captureResolution: CaptureResolution? {
        geometry?.captureResolution
    }

    var captureResolutionLabel: String {
        captureResolution?.label ?? "Unknown"
    }

    var qualityWarning: CaptureQualityWarning? {
        guard kind == .window, let captureResolution else {
            return nil
        }

        let minimum = CaptureResolution(width: 1280, height: 720)
        guard captureResolution.width < minimum.width || captureResolution.height < minimum.height else {
            return nil
        }

        return .sourceTooSmall(actual: captureResolution, minimum: minimum)
    }
}

struct ScreenRecordingConfiguration: Equatable {
    let source: ScreenCaptureSource
    let outputDirectory: URL
    let createdAt: Date

    init(source: ScreenCaptureSource, outputDirectory: URL, createdAt: Date = Date()) {
        self.source = source
        self.outputDirectory = outputDirectory
        self.createdAt = createdAt
    }

    func outputFileURL(createdAt: Date = Date()) -> URL {
        let timestamp = Self.outputTimestampFormatter.string(from: createdAt)
        let filename = "\(source.id)-\(timestamp).mov"

        return outputDirectory.appendingPathComponent(filename)
    }

    func recordingPackageDirectory(createdAt: Date = Date()) -> URL {
        let timestamp = Self.outputTimestampFormatter.string(from: createdAt)
        let packageName = "\(source.id)-\(timestamp).screencraft"

        return outputDirectory.appendingPathComponent(packageName, isDirectory: true)
    }

    func screenVideoFileURL(createdAt: Date = Date()) -> URL {
        recordingPackageDirectory(createdAt: createdAt)
            .appendingPathComponent(Self.screenVideoRelativePath)
    }

    var packageDirectory: URL {
        recordingPackageDirectory(createdAt: createdAt)
    }

    var screenVideoURL: URL {
        screenVideoFileURL(createdAt: createdAt)
    }

    static let screenVideoRelativePath = "media/screen.mov"

    private static let outputTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        // 文件名不应跟随用户时区变化，否则同一次录制在测试和文档中难以对应。
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter
    }()
}
