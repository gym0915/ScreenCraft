import Foundation
import Testing
@testable import ScreenCraft

struct MouseEventModelTests {
    @Test func captureRegionMapsGlobalPointIntoRetinaRecordingPixels() {
        let region = MouseEventCaptureRegion(
            origin: MouseEventLocation(x: 100, y: 200),
            size: MouseEventSize(width: 640, height: 360),
            backingScaleFactor: 2
        )

        let mappedLocation = region.recordingLocation(for: MouseEventLocation(x: 125.5, y: 250.25))

        #expect(mappedLocation == MouseEventLocation(x: 51, y: 100.5))
    }

    @Test func captureRegionHandlesNegativeDisplayOriginsAndRejectsOutsidePoints() {
        let region = MouseEventCaptureRegion(
            origin: MouseEventLocation(x: -1_920, y: 0),
            size: MouseEventSize(width: 1_920, height: 1_080),
            backingScaleFactor: 1
        )

        #expect(region.recordingLocation(for: MouseEventLocation(x: -1_910, y: 10)) == MouseEventLocation(x: 10, y: 10))
        #expect(region.recordingLocation(for: MouseEventLocation(x: 1, y: 10)) == nil)
    }

    @Test func mouseEventStoresGlobalAndRecordingLocations() {
        let event = MouseEvent(
            id: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
            kind: .leftClick,
            timestamp: 1.25,
            globalLocation: MouseEventLocation(x: 320, y: 240),
            recordingLocation: MouseEventLocation(x: 640, y: 480)
        )

        #expect(event.location == event.globalLocation)
        #expect(event.recordingLocation == MouseEventLocation(x: 640, y: 480))
    }
}
