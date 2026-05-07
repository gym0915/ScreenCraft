import Foundation
import Testing
@testable import ScreenCraft

struct ScreenCaptureModelsTests {
    @Test func windowSourceKeepsStableIdentityAndLabels() {
        let source = ScreenCaptureSource(
            id: "window-42",
            kind: .window,
            title: "Quarterly Plan",
            appName: "Notes"
        )

        #expect(source.id == "window-42")
        #expect(source.kind == .window)
        #expect(source.title == "Quarterly Plan")
        #expect(source.appName == "Notes")
        #expect(source.displayLabel == "Notes - Quarterly Plan")
    }

    @Test func displaySourceLabelFallsBackToTitle() {
        let source = ScreenCaptureSource(
            id: "display-1",
            kind: .display,
            title: "Built-in Retina Display",
            appName: nil
        )

        #expect(source.kind == .display)
        #expect(source.displayLabel == "Built-in Retina Display")
    }

    @Test func captureSourcesExposeRetinaCaptureResolutionFromPointGeometry() {
        let window = ScreenCaptureSource(
            id: "window-42",
            kind: .window,
            title: "Quarterly Plan",
            appName: "Notes",
            geometry: CaptureSourceGeometry(
                originX: 120,
                originY: 80,
                width: 640,
                height: 360,
                scale: 2
            )
        )

        #expect(window.captureResolution == CaptureResolution(width: 1280, height: 720))
        #expect(window.captureResolutionLabel == "1280 x 720")
    }

    @Test func displayAndRegionSourcesShareTheSameResolutionPolicy() {
        let display = ScreenCaptureSource(
            id: "display-1",
            kind: .display,
            title: "Display 1",
            appName: nil,
            geometry: CaptureSourceGeometry(
                originX: 0,
                originY: 0,
                width: 1512,
                height: 982,
                scale: 2
            )
        )
        let region = ScreenCaptureSource(
            id: "region-display-1",
            kind: .region,
            title: "Region on Display 1",
            appName: nil,
            geometry: CaptureSourceGeometry(
                originX: 100,
                originY: 120,
                width: 900,
                height: 506,
                scale: 2
            )
        )

        #expect(display.captureResolution == CaptureResolution(width: 3024, height: 1964))
        #expect(region.captureResolution == CaptureResolution(width: 1800, height: 1012))
    }

    @Test func smallWindowSourceReturnsQualityWarning() {
        let source = ScreenCaptureSource(
            id: "window-99",
            kind: .window,
            title: "Tiny Utility",
            appName: "Utility",
            geometry: CaptureSourceGeometry(
                originX: 0,
                originY: 0,
                width: 320,
                height: 240,
                scale: 1
            )
        )

        #expect(source.qualityWarning == .sourceTooSmall(
            actual: CaptureResolution(width: 320, height: 240),
            minimum: CaptureResolution(width: 1280, height: 720)
        ))
        #expect(source.qualityWarning?.message == "Capture source is 320 x 240. Enlarge the window before recording for a sharper 1080p export.")
    }

    @Test func windowGeometryPrefersFilterContentRectOverStaleWindowFrame() {
        let geometry = CaptureSourceGeometry.windowGeometry(
            windowFrame: CaptureSourceGeometry(
                originX: 0,
                originY: 0,
                width: 440,
                height: 354,
                scale: 1
            ),
            filterContentRect: CaptureSourceGeometry(
                originX: 0,
                originY: 0,
                width: 1920,
                height: 1080,
                scale: 2
            )
        )

        #expect(geometry.captureResolution == CaptureResolution(width: 3840, height: 2160))
    }

    @Test func recordingConfigurationBuildsMovOutputURLFromSourceAndDate() {
        let source = ScreenCaptureSource(
            id: "window-42",
            kind: .window,
            title: "Quarterly Plan",
            appName: "Notes"
        )
        let directory = URL(fileURLWithPath: "/tmp/screencraft-tests", isDirectory: true)
        let date = Date(timeIntervalSince1970: 1_798_676_496)
        let configuration = ScreenRecordingConfiguration(source: source, outputDirectory: directory)

        let outputURL = configuration.outputFileURL(createdAt: date)

        #expect(outputURL.path == "/tmp/screencraft-tests/window-42-20261231-002136.mov")
    }

    @Test func recordingConfigurationBuildsFormalPackageScreenVideoURL() {
        let source = ScreenCaptureSource(
            id: "window-42",
            kind: .window,
            title: "Quarterly Plan",
            appName: "Notes"
        )
        let directory = URL(fileURLWithPath: "/tmp/screencraft-tests", isDirectory: true)
        let date = Date(timeIntervalSince1970: 1_798_676_496)
        let configuration = ScreenRecordingConfiguration(source: source, outputDirectory: directory)

        let packageURL = configuration.recordingPackageDirectory(createdAt: date)
        let screenVideoURL = configuration.screenVideoFileURL(createdAt: date)

        #expect(packageURL.path == "/tmp/screencraft-tests/window-42-20261231-002136.screencraft")
        #expect(screenVideoURL.path == "/tmp/screencraft-tests/window-42-20261231-002136.screencraft/media/screen.mov")
        #expect(ScreenRecordingConfiguration.screenVideoRelativePath == "media/screen.mov")
    }
}
