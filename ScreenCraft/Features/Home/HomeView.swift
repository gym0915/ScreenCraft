import SwiftUI

struct HomeView: View {
    // ViewModel 由外部注入，方便预览、测试和后续真实环境切换复用同一个 View。
    @StateObject private var viewModel: HomeViewModel

    init(viewModel: HomeViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    var body: some View {
        // 初始 Home 是工程状态面板，优先展示依赖注入和权限 mock 是否接通。
        VStack(alignment: .leading, spacing: 24) {
            header
            permissionSection
            spikeSection
            microphoneSpikeSection
        }
        .padding(32)
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

    private var spikeSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Window Capture Spike")
                .font(.headline)

            HStack(spacing: 10) {
                Button {
                    runSpikeAction {
                        try await viewModel.refreshCaptureSources()
                    }
                } label: {
                    Label("Refresh Windows", systemImage: "arrow.clockwise")
                }
                .disabled(viewModel.isRefreshingCaptureSources || viewModel.isRecordingWindow)

                Button {
                    runSpikeAction {
                        try await viewModel.startSelectedWindowRecording()
                    }
                } label: {
                    Label("Start Recording Selected Window", systemImage: "record.circle")
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

            Picker("Window", selection: $viewModel.selectedCaptureSourceID) {
                if viewModel.captureSources.isEmpty {
                    Text("No windows loaded").tag(String?.none)
                }

                ForEach(viewModel.captureSources.filter { $0.kind == .window }) { source in
                    Text(source.displayLabel).tag(Optional(source.id))
                }
            }
            .labelsHidden()
            .frame(maxWidth: 520, alignment: .leading)
        }
    }

    private var statusPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.spikeStatusMessage)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)

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
