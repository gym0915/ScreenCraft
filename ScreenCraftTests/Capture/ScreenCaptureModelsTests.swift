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
}
