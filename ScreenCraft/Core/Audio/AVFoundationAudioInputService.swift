import AVFoundation
import Foundation

@MainActor
final class AVFoundationAudioInputService: AudioInputServicing {
    static let defaultRecorderSettings: [String: Any] = [
        AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
        AVSampleRateKey: 48_000.0,
        AVNumberOfChannelsKey: 1,
        AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
    ]

    private var state: AudioRecordingState = .idle
    private var activeSession: AudioRecordingSession?
    private var activeRecorder: AVAudioRecorder?

    func recordingState() async -> AudioRecordingState {
        state
    }

    func availableInputDevices() async throws -> [AudioInputDevice] {
        let defaultDeviceID = AVCaptureDevice.default(for: .audio)?.uniqueID
        return Self.discoverInputDevices(defaultDeviceID: defaultDeviceID)
    }

    func startRecording(
        deviceID: String?,
        outputDirectory: URL
    ) async throws -> AudioRecordingSession {
        guard case .idle = state else {
            throw AudioInputServiceError.alreadyRecording
        }

        let authorizationStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        let isAuthorized: Bool
        switch authorizationStatus {
        case .authorized:
            isAuthorized = true
        case .notDetermined:
            isAuthorized = await AVCaptureDevice.requestAccess(for: .audio)
        case .denied, .restricted:
            isAuthorized = false
        @unknown default:
            isAuthorized = false
        }

        guard isAuthorized else {
            throw AudioInputServiceError.permissionDenied("Microphone access is not granted.")
        }

        let selectedDeviceID = try resolvedDeviceID(for: deviceID)
        let outputURL = try Self.makeOutputURL(in: outputDirectory)
        let recorder: AVAudioRecorder
        do {
            recorder = try AVAudioRecorder(url: outputURL, settings: Self.defaultRecorderSettings)
            recorder.prepareToRecord()
        } catch {
            throw AudioInputServiceError.recordingFailed(error.localizedDescription)
        }

        guard recorder.record() else {
            throw AudioInputServiceError.recordingFailed("Unable to start microphone recording.")
        }

        // AVAudioRecorder 在 macOS 上不提供按 AVCaptureDevice 绑定输入设备的稳定入口；本 Spike 先使用系统默认输入。
        let session = AudioRecordingSession(
            id: UUID(),
            deviceID: selectedDeviceID,
            outputURL: outputURL,
            startedAt: Date()
        )
        activeRecorder = recorder
        activeSession = session
        state = .recording(session)
        return session
    }

    func stopRecording() async throws -> AudioRecordingResult {
        guard let activeSession, let activeRecorder else {
            throw AudioInputServiceError.notRecording
        }

        let duration = activeRecorder.currentTime
        activeRecorder.stop()

        let fileSize = try? FileManager.default
            .attributesOfItem(atPath: activeSession.outputURL.path)[.size] as? NSNumber

        self.activeRecorder = nil
        self.activeSession = nil
        state = .idle

        return AudioRecordingResult(
            session: activeSession,
            duration: duration,
            fileSizeBytes: fileSize?.int64Value
        )
    }

    private func resolvedDeviceID(for requestedDeviceID: String?) throws -> String? {
        let defaultDeviceID = AVCaptureDevice.default(for: .audio)?.uniqueID
        let devices = Self.discoverInputDevices(defaultDeviceID: defaultDeviceID)

        guard let requestedDeviceID else {
            return defaultDeviceID
        }

        guard devices.contains(where: { $0.id == requestedDeviceID }) else {
            throw AudioInputServiceError.deviceUnavailable
        }

        return requestedDeviceID
    }

    private static func discoverInputDevices(defaultDeviceID: String?) -> [AudioInputDevice] {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.microphone, .external],
            mediaType: .audio,
            position: .unspecified
        )

        return discoverySession.devices.map { device in
            AudioInputDevice(
                id: device.uniqueID,
                name: device.localizedName,
                isDefault: device.uniqueID == defaultDeviceID
            )
        }
    }

    private static func makeOutputURL(in outputDirectory: URL) throws -> URL {
        try FileManager.default.createDirectory(
            at: outputDirectory,
            withIntermediateDirectories: true
        )

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"

        return outputDirectory.appendingPathComponent(
            "microphone-\(formatter.string(from: Date())).m4a"
        )
    }
}
