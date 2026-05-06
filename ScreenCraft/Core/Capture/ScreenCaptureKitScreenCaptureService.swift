import AVFoundation
import CoreMedia
import Foundation
@preconcurrency import ScreenCaptureKit

@MainActor
final class ScreenCaptureKitScreenCaptureService: NSObject, ScreenCaptureServicing {
    private var state: ScreenRecordingState = .idle
    private var windowsBySourceID: [String: SCWindow] = [:]
    private var displaysBySourceID: [String: SCDisplay] = [:]
    private var activeStream: SCStream?
    private var activeStreamOutput: ScreenCaptureKitStreamOutput?
    private var activeRecordingOutput: SCRecordingOutput?
    private var activeRecordingDelegate: ScreenCaptureKitRecordingOutputDelegate?
    private var activeOutputURL: URL?
    private var activeStartedAt: Date?
    private let videoSampleQueue = DispatchQueue(label: "ScreenCraft.ScreenCaptureKit.video")

    func recordingState() async -> ScreenRecordingState {
        state
    }

    func availableSources() async throws -> [ScreenCaptureSource] {
        let content: SCShareableContent

        do {
            content = try await SCShareableContent.excludingDesktopWindows(
                false,
                onScreenWindowsOnly: true
            )
        } catch {
            let message = """
            ScreenCaptureKit could not list windows. Enable Screen & System Audio Recording in System Settings -> Privacy & Security, then restart ScreenCraft if macOS asks for it. \(error.localizedDescription)
            """
            state = .unavailable(message)
            throw ScreenCaptureServiceError.permissionDenied(message)
        }

        let displays = content.displays.map { display in
            let source = ScreenCaptureSource(
                id: Self.sourceID(for: display),
                kind: .display,
                title: "Display \(display.displayID)",
                appName: nil
            )
            displaysBySourceID[source.id] = display
            return source
        }

        let windows = content.windows
            .filter { window in
                window.isOnScreen && window.windowLayer == 0
            }
            .map { window in
                let title = window.title?.isEmpty == false ? window.title! : "Untitled Window"
                let source = ScreenCaptureSource(
                    id: Self.sourceID(for: window),
                    kind: .window,
                    title: title,
                    appName: window.owningApplication?.applicationName
                )
                windowsBySourceID[source.id] = window
                return source
            }
            .sorted { (first: ScreenCaptureSource, second: ScreenCaptureSource) in
                first.displayLabel.localizedCaseInsensitiveCompare(second.displayLabel) == .orderedAscending
            }

        state = activeStream == nil ? .idle : .recording
        return displays + windows
    }

    func startRecording(configuration: ScreenRecordingConfiguration) async throws {
        guard state != .recording else {
            throw ScreenCaptureServiceError.alreadyRecording
        }
        guard configuration.source.kind == .window else {
            throw ScreenCaptureServiceError.displayRecordingUnsupported
        }

        let window = try await window(for: configuration.source)
        let outputURL = configuration.outputFileURL()
        try prepareOutputURL(outputURL)

        let filter = SCContentFilter(desktopIndependentWindow: window)
        let streamConfiguration = streamConfiguration(for: window, filter: filter)
        let stream = SCStream(filter: filter, configuration: streamConfiguration, delegate: nil)
        let streamOutput = ScreenCaptureKitStreamOutput()

        let recordingConfiguration = SCRecordingOutputConfiguration()
        recordingConfiguration.outputURL = outputURL
        recordingConfiguration.outputFileType = .mov
        recordingConfiguration.videoCodecType = .h264

        let recordingDelegate = ScreenCaptureKitRecordingOutputDelegate()
        let recordingOutput = SCRecordingOutput(
            configuration: recordingConfiguration,
            delegate: recordingDelegate
        )

        do {
            // SCRecordingOutput 仍依赖 stream 的 screen output 管线；不注册输出时系统会丢帧并生成不可播放文件。
            try stream.addStreamOutput(streamOutput, type: .screen, sampleHandlerQueue: videoSampleQueue)
            try stream.addRecordingOutput(recordingOutput)
            try await stream.startCapture()
        } catch {
            cleanupRecordingState()
            throw ScreenCaptureServiceError.recordingFailed(error.localizedDescription)
        }

        activeStream = stream
        activeStreamOutput = streamOutput
        activeRecordingOutput = recordingOutput
        activeRecordingDelegate = recordingDelegate
        activeOutputURL = outputURL
        activeStartedAt = Date()
        state = .recording
    }

    func stopRecording() async throws -> RecordingProject {
        guard let activeStream, let activeRecordingOutput, let activeOutputURL else {
            throw ScreenCaptureServiceError.notRecording
        }

        let duration = activeRecordingOutput.recordedDuration.seconds.isFinite
            ? activeRecordingOutput.recordedDuration.seconds
            : Date().timeIntervalSince(activeStartedAt ?? Date())

        do {
            // 让 SCStream 停止时一并完成 recording output 写入；提前 removeRecordingOutput 会导致文件收尾不稳定。
            try await activeStream.stopCapture()
        } catch {
            cleanupRecordingState()
            throw ScreenCaptureServiceError.recordingFailed(error.localizedDescription)
        }

        cleanupRecordingState()

        return RecordingProject(
            name: "Window Capture Spike",
            media: ProjectMedia(screenVideoURL: activeOutputURL),
            duration: duration
        )
    }

    private func window(for source: ScreenCaptureSource) async throws -> SCWindow {
        if let cachedWindow = windowsBySourceID[source.id] {
            return cachedWindow
        }

        _ = try await availableSources()

        guard let refreshedWindow = windowsBySourceID[source.id] else {
            throw ScreenCaptureServiceError.sourceUnavailable
        }

        return refreshedWindow
    }

    private func prepareOutputURL(_ outputURL: URL) throws {
        let directory = outputURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }
    }

    private func streamConfiguration(
        for window: SCWindow,
        filter: SCContentFilter
    ) -> SCStreamConfiguration {
        let configuration = SCStreamConfiguration()
        let scale = CGFloat(max(filter.pointPixelScale, 1))
        let width = max(2, Int((window.frame.width * scale).rounded()))
        let height = max(2, Int((window.frame.height * scale).rounded()))

        configuration.width = width
        configuration.height = height
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        configuration.queueDepth = 5
        configuration.scalesToFit = true
        configuration.showsCursor = true
        configuration.capturesAudio = false
        configuration.captureMicrophone = false
        configuration.ignoreShadowsSingleWindow = false
        configuration.streamName = "ScreenCraft Window Capture Spike"

        return configuration
    }

    private func cleanupRecordingState() {
        activeStream = nil
        activeStreamOutput = nil
        activeRecordingOutput = nil
        activeRecordingDelegate = nil
        activeOutputURL = nil
        activeStartedAt = nil
        state = .idle
    }

    private static func sourceID(for display: SCDisplay) -> String {
        "display-\(display.displayID)"
    }

    private static func sourceID(for window: SCWindow) -> String {
        "window-\(window.windowID)"
    }
}

private final class ScreenCaptureKitStreamOutput: NSObject, SCStreamOutput {
    nonisolated func stream(
        _ stream: SCStream,
        didOutputSampleBuffer sampleBuffer: CMSampleBuffer,
        of type: SCStreamOutputType
    ) {
        // Spike 阶段只需要让 ScreenCaptureKit 的 screen output 管线保持有效；文件写入交给 SCRecordingOutput。
    }
}

private final class ScreenCaptureKitRecordingOutputDelegate: NSObject, SCRecordingOutputDelegate {
    nonisolated func recordingOutput(
        _ recordingOutput: SCRecordingOutput,
        didFailWithError error: Error
    ) {
        // Spike UI 通过 stop/start 抛错呈现失败；delegate 先保留以满足 SCRecordingOutput 生命周期要求。
    }
}
