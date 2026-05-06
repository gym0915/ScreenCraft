import Foundation

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
    }

    let id: String
    let kind: Kind
    let title: String
    let appName: String?

    var displayLabel: String {
        guard let appName, !appName.isEmpty else {
            return title
        }

        return "\(appName) - \(title)"
    }
}

struct ScreenRecordingConfiguration: Equatable {
    let source: ScreenCaptureSource
    let outputDirectory: URL

    func outputFileURL(createdAt: Date = Date()) -> URL {
        let timestamp = Self.outputTimestampFormatter.string(from: createdAt)
        let filename = "\(source.id)-\(timestamp).mov"

        return outputDirectory.appendingPathComponent(filename)
    }

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
