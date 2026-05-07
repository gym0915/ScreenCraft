import CoreGraphics
import Foundation
import Testing
@testable import ScreenCraft

struct ZoomAnalyzerTests {
    @Test func clickEventsGenerateAutomaticZoomSegments() {
        let analyzer = ZoomAnalyzer(
            configuration: ZoomAnalysisConfiguration(
                recordingSize: MouseEventSize(width: 1_920, height: 1_080),
                scale: 1.6,
                segmentDuration: 1.2
            )
        )
        let events = [
            mouseEvent(kind: .move, timestamp: 0.8, x: 300, y: 300),
            mouseEvent(kind: .leftClick, timestamp: 1.0, x: 960, y: 540)
        ]

        let segments = analyzer.segments(from: events)

        #expect(segments.count == 1)
        #expect(segments[0].source == .automatic)
        #expect(segments[0].start.isAlmostEqual(to: 0.85))
        #expect(segments[0].end.isAlmostEqual(to: 2.05))
        #expect(segments[0].scale == 1.6)
        #expect(segments[0].targetRect == CGRect(x: 360, y: 202.5, width: 1_200, height: 675))
    }

    @Test func nearbyClicksMergeIntoOneStableSegment() {
        let analyzer = ZoomAnalyzer(
            configuration: ZoomAnalysisConfiguration(
                recordingSize: MouseEventSize(width: 1_920, height: 1_080),
                mergeInterval: 0.6,
                mergeDistance: 120
            )
        )
        let events = [
            mouseEvent(kind: .leftClick, timestamp: 1.0, x: 900, y: 520),
            mouseEvent(kind: .leftClick, timestamp: 1.4, x: 950, y: 560)
        ]

        let segments = analyzer.segments(from: events)

        #expect(segments.count == 1)
        #expect(segments[0].start.isAlmostEqual(to: 0.85))
        #expect(segments[0].end.isAlmostEqual(to: 2.45))
    }

    @Test func distantAdjacentClicksDoNotOverlap() {
        let analyzer = ZoomAnalyzer(
            configuration: ZoomAnalysisConfiguration(
                recordingSize: MouseEventSize(width: 1_920, height: 1_080),
                segmentDuration: 1.2,
                mergeInterval: 0.6,
                mergeDistance: 120
            )
        )
        let events = [
            mouseEvent(kind: .leftClick, timestamp: 1.0, x: 200, y: 200),
            mouseEvent(kind: .leftClick, timestamp: 1.4, x: 1_700, y: 900)
        ]

        let segments = analyzer.segments(from: events)

        #expect(segments.count == 2)
        #expect(segments[0].end.isAlmostEqual(to: segments[1].start))
        #expect(segments[1].end.isAlmostEqual(to: 2.45))
    }

    @Test func edgeClicksClampTargetRectInsideRecordingBounds() {
        let analyzer = ZoomAnalyzer(
            configuration: ZoomAnalysisConfiguration(
                recordingSize: MouseEventSize(width: 1_920, height: 1_080),
                scale: 1.6
            )
        )
        let events = [
            mouseEvent(kind: .leftClick, timestamp: 1.0, x: 10, y: 10),
            mouseEvent(kind: .rightClick, timestamp: 3.0, x: 1_910, y: 1_070)
        ]

        let segments = analyzer.segments(from: events)

        #expect(segments.count == 2)
        #expect(segments[0].targetRect == CGRect(x: 0, y: 0, width: 1_200, height: 675))
        #expect(segments[1].targetRect == CGRect(x: 720, y: 405, width: 1_200, height: 675))
    }

    @Test func disabledAnalyzerReturnsNoSegmentsAndGeneratedSegmentsCanBeEdited() {
        let disabledAnalyzer = ZoomAnalyzer(
            configuration: ZoomAnalysisConfiguration(
                isEnabled: false,
                recordingSize: MouseEventSize(width: 1_920, height: 1_080)
            )
        )
        let enabledAnalyzer = ZoomAnalyzer(
            configuration: ZoomAnalysisConfiguration(
                recordingSize: MouseEventSize(width: 1_920, height: 1_080)
            )
        )
        let events = [
            mouseEvent(kind: .leftClick, timestamp: 1.0, x: 960, y: 540)
        ]

        #expect(disabledAnalyzer.segments(from: events).isEmpty)

        var segment = enabledAnalyzer.segments(from: events)[0]
        segment.start = 0.25
        segment.end = 1.75
        segment.scale = 1.25
        segment.targetRect = CGRect(x: 100, y: 100, width: 1_280, height: 720)

        #expect(segment.source == .automatic)
        #expect(segment.start == 0.25)
        #expect(segment.end == 1.75)
        #expect(segment.scale == 1.25)
        #expect(segment.targetRect == CGRect(x: 100, y: 100, width: 1_280, height: 720))
    }

    private func mouseEvent(
        kind: MouseEventKind,
        timestamp: TimeInterval,
        x: Double,
        y: Double
    ) -> MouseEvent {
        MouseEvent(
            kind: kind,
            timestamp: timestamp,
            globalLocation: MouseEventLocation(x: x, y: y),
            recordingLocation: MouseEventLocation(x: x, y: y)
        )
    }
}

private extension Double {
    func isAlmostEqual(to other: Double, tolerance: Double = 0.000_001) -> Bool {
        abs(self - other) <= tolerance
    }
}
