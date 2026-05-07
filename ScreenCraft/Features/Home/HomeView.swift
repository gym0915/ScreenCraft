import SwiftUI

struct HomeView: View {
    // ViewModel 由外部注入，方便预览、测试和后续真实环境切换复用同一个 View。
    @StateObject private var viewModel: HomeViewModel

    init(viewModel: HomeViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        // 初始 Home 是工程状态面板，优先展示依赖注入和权限 mock 是否接通。
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                header
                permissionSection
                captureConfigurationSection
                microphoneSpikeSection
                mouseEventSpikeSection
                timelinePreviewSection
            }
            .padding(32)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(minWidth: 820, minHeight: 620, alignment: .topLeading)
        .task {
            await viewModel.loadFoundationState()
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ScreenCraft")
                .font(.largeTitle)
                .fontWeight(.semibold)

            Text(viewModel.foundationStatus)
                .foregroundStyle(.secondary)
        }
    }

    private var permissionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Permissions")
                .font(.headline)

            VStack(spacing: 0) {
                ForEach(viewModel.permissionRows) { row in
                    permissionRow(row)

                    if row.id != viewModel.permissionRows.last?.id {
                        Divider()
                    }
                }
            }
            .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 8))
        }
        .frame(maxWidth: 460, alignment: .leading)
    }

    private func permissionRow(_ row: HomePermissionRow) -> some View {
        HStack(spacing: 12) {
            statusDot(for: row)

            Text(row.title)
                .font(.body)

            Spacer()

            Text(row.statusText)
                .font(.callout)
                .foregroundStyle(row.isReserved ? .secondary : .primary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func statusDot(for row: HomePermissionRow) -> some View {
        Circle()
            .fill(row.isReserved ? Color.secondary : Color.accentColor)
            .opacity(row.isReserved ? 0.45 : 0.8)
            .frame(width: 8, height: 8)
            .accessibilityHidden(true)
    }

    private var captureConfigurationSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Capture Configuration")
                .font(.headline)

            HStack(spacing: 10) {
                Button {
                    runSpikeAction {
                        try await viewModel.refreshCaptureSources()
                    }
                } label: {
                    Label("Refresh Sources", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isRefreshingCaptureSources || viewModel.isRecordingWindow)

                Button {
                    runSpikeAction {
                        try await viewModel.startSelectedWindowRecording()
                    }
                } label: {
                    Label("Start Recording Source", systemImage: "record.circle")
                }
                .disabled(!viewModel.canStartWindowRecording)

                Button {
                    runSpikeAction {
                        try await viewModel.stopWindowRecording()
                    }
                } label: {
                    Label("Stop Recording", systemImage: "stop.circle")
                }
                .disabled(!viewModel.canStopWindowRecording)
            }

            sourcePicker
            statusPanel
        }
        .frame(maxWidth: 720, alignment: .leading)
    }

    private var sourcePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sources")
                .font(.subheadline)
                .fontWeight(.medium)

            Picker("Source", selection: $viewModel.selectedCaptureSourceID) {
                if viewModel.captureSources.isEmpty {
                    Text("No sources loaded").tag(String?.none)
                }

                ForEach(viewModel.captureSources) { source in
                    Text("\(sourceKindLabel(for: source.kind)): \(source.displayLabel)")
                        .tag(Optional(source.id))
                }
            }
            .frame(maxWidth: 520, alignment: .leading)
        }
    }

    private var statusPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.spikeStatusMessage)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            VStack(alignment: .leading, spacing: 4) {
                Text("Source: \(viewModel.selectedCaptureSourceKindLabel)")
                Text("Capture Resolution: \(viewModel.selectedCaptureResolutionLabel)")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .textSelection(.enabled)

            if let qualityWarning = viewModel.selectedCaptureQualityWarningMessage {
                Text(qualityWarning)
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .textSelection(.enabled)
            }

            if let outputFilePath = viewModel.outputFilePath {
                Text(outputFilePath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .textSelection(.enabled)
            }

            if let permissionHelpMessage = viewModel.permissionHelpMessage {
                VStack(alignment: .leading, spacing: 6) {
                    Text(permissionHelpMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Link(
                        "Open Screen Recording Settings",
                        destination: HomeViewModel.screenRecordingPermissionURL
                    )
                    .font(.caption)
                }
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
    }

    private func sourceKindLabel(for kind: ScreenCaptureSource.Kind) -> String {
        switch kind {
        case .display:
            return "Display"
        case .window:
            return "Window"
        case .region:
            return "Region"
        }
    }

    private var microphoneSpikeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Microphone Spike")
                .font(.headline)

            HStack(spacing: 10) {
                Button {
                    runSpikeAction {
                        try await viewModel.refreshAudioInputDevices()
                    }
                } label: {
                    Label("Refresh Microphones", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isRefreshingAudioInputDevices || viewModel.isRecordingMicrophone)

                Button {
                    runSpikeAction {
                        try await viewModel.startMicrophoneRecording()
                    }
                } label: {
                    Label("Start Microphone Recording", systemImage: "mic.circle")
                }
                .disabled(!viewModel.canStartMicrophoneRecording)

                Button {
                    runSpikeAction {
                        try await viewModel.stopMicrophoneRecording()
                    }
                } label: {
                    Label("Stop Microphone Recording", systemImage: "stop.circle")
                }
                .disabled(!viewModel.canStopMicrophoneRecording)
            }

            audioInputPicker
            audioStatusPanel
        }
        .frame(maxWidth: 720, alignment: .leading)
    }

    private var audioInputPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Microphones")
                .font(.subheadline)
                .fontWeight(.medium)

            Picker("Microphone", selection: $viewModel.selectedAudioInputDeviceID) {
                if viewModel.audioInputDevices.isEmpty {
                    Text("No microphones loaded").tag(String?.none)
                }

                ForEach(viewModel.audioInputDevices) { device in
                    Text(device.isDefault ? "\(device.name) (Default)" : device.name)
                        .tag(Optional(device.id))
                }
            }
            .labelsHidden()
            .frame(maxWidth: 520, alignment: .leading)
        }
    }

    private var audioStatusPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.audioSpikeStatusMessage)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            if let audioOutputFilePath = viewModel.audioOutputFilePath {
                Text(audioOutputFilePath)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .textSelection(.enabled)
            }

            if let audioPermissionHelpMessage = viewModel.audioPermissionHelpMessage {
                VStack(alignment: .leading, spacing: 6) {
                    Text(audioPermissionHelpMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Link(
                        "Open Microphone Settings",
                        destination: SystemPermissionManager.microphonePermissionURL
                    )
                    .font(.caption)
                }
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
    }

    private var mouseEventSpikeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Mouse Event Spike")
                .font(.headline)

            HStack(spacing: 10) {
                Button {
                    runSpikeAction {
                        try await viewModel.startMouseEventRecording()
                    }
                } label: {
                    Label("Start Mouse Events", systemImage: "cursorarrow.click")
                }
                .disabled(!viewModel.canStartMouseEventRecording)

                Button {
                    runSpikeAction {
                        try await viewModel.stopMouseEventRecording()
                    }
                } label: {
                    Label("Stop Mouse Events", systemImage: "stop.circle")
                }
                .disabled(!viewModel.canStopMouseEventRecording)
            }

            mouseEventStatusPanel
        }
        .frame(maxWidth: 720, alignment: .leading)
    }

    private var mouseEventStatusPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.mouseEventSpikeStatusMessage)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

            Text("Events: \(viewModel.mouseEventCount)")
                .font(.caption)
                .foregroundStyle(.secondary)

            if !viewModel.mouseEventDebugLines.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(viewModel.mouseEventDebugLines, id: \.self) { line in
                        Text(line)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .textSelection(.enabled)
                    }
                }
            }

            if let mouseEventPermissionHelpMessage = viewModel.mouseEventPermissionHelpMessage {
                VStack(alignment: .leading, spacing: 6) {
                    Text(mouseEventPermissionHelpMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Link(
                        "Open Input Monitoring Settings",
                        destination: HomeViewModel.inputMonitoringPermissionURL
                    )
                    .font(.caption)
                }
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
    }

    private var timelinePreviewSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Timeline Preview")
                .font(.headline)

            if let preview = viewModel.timelinePreview {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(viewModel.timelinePreviewProjectName ?? "Latest Recording")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Text("Duration \(preview.durationLabel) · Trim \(preview.trimLabel)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text("\(preview.segments.count) zoom")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    timelineBar(preview)

                    if preview.segments.isEmpty {
                        Text("No zoom segments generated.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(preview.segments) { segment in
                                zoomSegmentRow(segment)
                            }
                        }
                    }
                }
                .padding(12)
                .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
            } else {
                Text("Record a source with mouse clicks to generate automatic zoom segments.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.quaternary.opacity(0.25), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .frame(maxWidth: 720, alignment: .leading)
    }

    private func timelineBar(_ preview: TimelinePreview) -> some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(.secondary.opacity(0.16))

                ForEach(preview.segments) { segment in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(segment.sourceLabel == "Auto" ? Color.accentColor.opacity(0.82) : Color.orange.opacity(0.82))
                        .frame(width: max(proxy.size.width * segment.widthFraction, 3))
                        .offset(x: proxy.size.width * segment.startFraction)
                        .accessibilityLabel("\(segment.sourceLabel) zoom \(segment.startLabel) to \(segment.endLabel)")
                }
            }
        }
        .frame(height: 24)
        .accessibilityElement(children: .contain)
    }

    private func zoomSegmentRow(_ segment: TimelinePreviewSegment) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(segment.sourceLabel == "Auto" ? Color.accentColor : Color.orange)
                .frame(width: 7, height: 7)
                .accessibilityHidden(true)

            Text("\(segment.sourceLabel) · \(segment.startLabel)-\(segment.endLabel)")
                .font(.caption.monospacedDigit())

            Spacer()

            Text(segment.scaleLabel)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
        }
    }

    private func runSpikeAction(_ action: @escaping () async throws -> Void) {
        Task {
            do {
                try await action()
            } catch {
                // ViewModel 已经把错误转成 UI 状态；View 层只负责启动异步命令。
            }
        }
    }
}

#Preview {
    // 预览固定使用 mock，保证设计时不会访问屏幕录制、麦克风或输入监听能力。
    HomeView(viewModel: HomeViewModel(environment: .mock))
}
