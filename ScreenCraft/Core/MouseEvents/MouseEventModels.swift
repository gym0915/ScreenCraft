import CoreGraphics
import Foundation

// MouseEvent 保存时间线需要的鼠标事件摘要，不直接依赖 NSEvent，方便测试和序列化。
struct MouseEvent: Identifiable, Codable, Equatable {
    let id: UUID
    let kind: MouseEventKind
    let timestamp: TimeInterval
    let location: MouseEventLocation
    let recordingLocation: MouseEventLocation?

    var globalLocation: MouseEventLocation {
        location
    }

    init(
        id: UUID = UUID(),
        kind: MouseEventKind,
        timestamp: TimeInterval,
        location: MouseEventLocation,
        recordingLocation: MouseEventLocation? = nil
    ) {
        self.id = id
        self.kind = kind
        self.timestamp = timestamp
        self.location = location
        self.recordingLocation = recordingLocation
    }

    init(
        id: UUID = UUID(),
        kind: MouseEventKind,
        timestamp: TimeInterval,
        globalLocation: MouseEventLocation,
        recordingLocation: MouseEventLocation? = nil
    ) {
        self.init(
            id: id,
            kind: kind,
            timestamp: timestamp,
            location: globalLocation,
            recordingLocation: recordingLocation
        )
    }
}

// 事件类型先覆盖时间线展示需要的最小集合，真实监听策略留到输入事件阶段实现。
enum MouseEventKind: String, Codable, Equatable {
    case move
    case leftClick
    case rightClick

    // drag 先作为时间线数据能力保留；基础脚手架阶段不会监听真实输入事件。
    case drag
}

// 使用 Double 坐标而不是 AppKit 类型，保持模型层和平台 UI 解耦。
struct MouseEventLocation: Codable, Equatable {
    let x: Double
    let y: Double
}

struct MouseEventSize: Codable, Equatable {
    let width: Double
    let height: Double
}

struct MouseEventCaptureRegion: Codable, Equatable {
    let origin: MouseEventLocation
    let size: MouseEventSize
    let backingScaleFactor: Double

    func recordingLocation(for globalLocation: MouseEventLocation) -> MouseEventLocation? {
        guard contains(globalLocation) else {
            return nil
        }

        return MouseEventLocation(
            x: (globalLocation.x - origin.x) * backingScaleFactor,
            y: (globalLocation.y - origin.y) * backingScaleFactor
        )
    }

    private func contains(_ globalLocation: MouseEventLocation) -> Bool {
        globalLocation.x >= origin.x
            && globalLocation.x < origin.x + size.width
            && globalLocation.y >= origin.y
            && globalLocation.y < origin.y + size.height
    }

    static let debugRetinaFixture = MouseEventCaptureRegion(
        origin: MouseEventLocation(x: 100, y: 200),
        size: MouseEventSize(width: 640, height: 360),
        backingScaleFactor: 2
    )

    static func mainDisplay(displayID: CGDirectDisplayID = CGMainDisplayID()) -> MouseEventCaptureRegion {
        let bounds = CGDisplayBounds(displayID)
        let pixelWidth = Double(CGDisplayPixelsWide(displayID))
        let scale = bounds.width > 0 ? pixelWidth / bounds.width : 1

        return MouseEventCaptureRegion(
            origin: MouseEventLocation(x: bounds.origin.x, y: bounds.origin.y),
            size: MouseEventSize(width: bounds.width, height: bounds.height),
            backingScaleFactor: scale
        )
    }
}

struct MouseEventRecordingSession: Equatable {
    let id: UUID
    let startedAt: Date
    let captureRegion: MouseEventCaptureRegion
}

struct MouseEventRecordingResult: Equatable {
    let session: MouseEventRecordingSession
    let events: [MouseEvent]
}

enum MouseEventRecordingState: Equatable {
    case idle
    case recording(MouseEventRecordingSession)
    case unavailable(String)
}

enum MouseEventServiceError: LocalizedError, Equatable {
    case permissionDenied(String)
    case alreadyRecording
    case notRecording
    case eventTapUnavailable(String)

    var errorDescription: String? {
        switch self {
        case .permissionDenied(let message):
            return message
        case .alreadyRecording:
            return "Mouse event recording is already in progress."
        case .notRecording:
            return "No mouse event recording is currently in progress."
        case .eventTapUnavailable(let message):
            return message
        }
    }
}
