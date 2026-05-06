import CoreGraphics
import Foundation

protocol MouseEventServicing {
    func recordingState() async -> MouseEventRecordingState
    func startRecording(captureRegion: MouseEventCaptureRegion) async throws -> MouseEventRecordingSession
    func stopRecording() async throws -> MouseEventRecordingResult
    func recordedEvents() async -> [MouseEvent]
}

@MainActor
final class MockMouseEventService: MouseEventServicing {
    private let seedEvents: [MouseEvent]
    private var activeSession: MouseEventRecordingSession?
    private var events: [MouseEvent] = []

    init(seedEvents: [MouseEvent] = []) {
        self.seedEvents = seedEvents
    }

    func recordingState() async -> MouseEventRecordingState {
        activeSession.map(MouseEventRecordingState.recording) ?? .idle
    }

    func startRecording(captureRegion: MouseEventCaptureRegion) async throws -> MouseEventRecordingSession {
        guard activeSession == nil else {
            throw MouseEventServiceError.alreadyRecording
        }

        let session = MouseEventRecordingSession(
            id: UUID(),
            startedAt: Date(),
            captureRegion: captureRegion
        )
        activeSession = session
        events = []

        return session
    }

    func stopRecording() async throws -> MouseEventRecordingResult {
        guard let activeSession else {
            throw MouseEventServiceError.notRecording
        }

        let mappedEvents = seedEvents.map { event in
            MouseEvent(
                id: event.id,
                kind: event.kind,
                timestamp: event.timestamp,
                globalLocation: event.globalLocation,
                recordingLocation: activeSession.captureRegion.recordingLocation(for: event.globalLocation)
            )
        }

        events = mappedEvents
        self.activeSession = nil

        return MouseEventRecordingResult(session: activeSession, events: mappedEvents)
    }

    func recordedEvents() async -> [MouseEvent] {
        events
    }
}

@MainActor
final class CoreGraphicsEventTapMouseEventService: MouseEventServicing {
    private var activeSession: MouseEventRecordingSession?
    private var events: [MouseEvent] = []
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    func recordingState() async -> MouseEventRecordingState {
        activeSession.map(MouseEventRecordingState.recording) ?? .idle
    }

    func startRecording(captureRegion: MouseEventCaptureRegion) async throws -> MouseEventRecordingSession {
        guard activeSession == nil else {
            throw MouseEventServiceError.alreadyRecording
        }

        let session = MouseEventRecordingSession(
            id: UUID(),
            startedAt: Date(),
            captureRegion: captureRegion
        )
        events = []

        let mask = Self.eventMask
        let userInfo = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: Self.eventTapCallback,
            userInfo: userInfo
        ) else {
            throw MouseEventServiceError.permissionDenied(Self.permissionDeniedMessage)
        }

        guard let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0) else {
            throw MouseEventServiceError.eventTapUnavailable("Unable to create mouse event run loop source.")
        }

        activeSession = session
        eventTap = tap
        runLoopSource = source

        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        return session
    }

    func stopRecording() async throws -> MouseEventRecordingResult {
        guard let activeSession else {
            throw MouseEventServiceError.notRecording
        }

        stopEventTap()
        self.activeSession = nil

        return MouseEventRecordingResult(session: activeSession, events: events)
    }

    func recordedEvents() async -> [MouseEvent] {
        events
    }

    private func append(cgEvent: CGEvent, type: CGEventType) {
        guard let activeSession, let kind = MouseEventKind(cgEventType: type) else {
            return
        }

        let globalLocation = MouseEventLocation(
            x: cgEvent.location.x,
            y: cgEvent.location.y
        )
        let recordingLocation = activeSession.captureRegion.recordingLocation(for: globalLocation)
        let timestamp = Date().timeIntervalSince(activeSession.startedAt)

        events.append(MouseEvent(
            kind: kind,
            timestamp: timestamp,
            globalLocation: globalLocation,
            recordingLocation: recordingLocation
        ))
    }

    private func stopEventTap() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }

        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        runLoopSource = nil
        eventTap = nil
    }

    private static let eventTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else {
            return Unmanaged.passUnretained(event)
        }

        let service = Unmanaged<CoreGraphicsEventTapMouseEventService>
            .fromOpaque(userInfo)
            .takeUnretainedValue()

        Task { @MainActor in
            service.append(cgEvent: event, type: type)
        }

        return Unmanaged.passUnretained(event)
    }

    private static let eventMask: CGEventMask = [
        CGEventType.mouseMoved,
        .leftMouseDown,
        .rightMouseDown,
        .leftMouseDragged,
        .rightMouseDragged
    ].reduce(CGEventMask(0)) { mask, type in
        mask | CGEventMask(1 << type.rawValue)
    }

    private static let permissionDeniedMessage = "Enable Input Monitoring or Accessibility for ScreenCraft to record global mouse events."
}

private extension MouseEventKind {
    init?(cgEventType: CGEventType) {
        switch cgEventType {
        case .mouseMoved:
            self = .move
        case .leftMouseDown:
            self = .leftClick
        case .rightMouseDown:
            self = .rightClick
        case .leftMouseDragged, .rightMouseDragged:
            self = .drag
        default:
            return nil
        }
    }
}
