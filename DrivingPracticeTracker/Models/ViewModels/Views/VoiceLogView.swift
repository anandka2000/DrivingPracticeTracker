import SwiftUI

struct VoiceLogView: View {
    @StateObject private var vm = VoiceLogManager()
    @Environment(\.dismiss) private var dismiss
    let onConfirm: (VoiceLogManager.ParsedSession) -> Void

    @State private var selectedSegment = 0

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Mode picker
                Picker("Mode", selection: $selectedSegment) {
                    Text("Describe Drive").tag(0)
                    Text("Start/Stop Timer").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 12)
                .onChange(of: selectedSegment) { _, newVal in
                    vm.timerMode = (newVal == 1)
                    // Stop any in-progress recording when switching modes
                    if vm.isRecording { vm.stopRecording() }
                    vm.sessionInProgress = false
                    vm.sessionElapsedText = "00:00"
                    vm.transcript = ""
                    vm.parsedSession = nil
                }

                ScrollView {
                    if selectedSegment == 0 {
                        describeModeContent
                    } else {
                        timerModeContent
                    }
                }
            }
            .navigationTitle("Voice Log")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        vm.stopRecording()
                        dismiss()
                    }
                }
            }
            .onDisappear {
                if vm.isRecording { vm.stopRecording() }
            }
        }
    }

    // MARK: - Describe Mode

    private var describeModeContent: some View {
        VStack(spacing: 28) {
            // Status label
            Text(vm.isRecording ? "Listening…" : "Tap the mic to start")
                .font(.headline)
                .foregroundStyle(vm.isRecording ? .red : .secondary)

            // Mic button with pulse
            ZStack {
                if vm.isRecording {
                    Circle()
                        .fill(Color.red.opacity(0.12))
                        .frame(width: 140, height: 140)
                        .scaleEffect(vm.isRecording ? 1.25 : 1.0)
                        .animation(
                            .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                            value: vm.isRecording
                        )
                }

                Button {
                    Task {
                        if vm.isRecording {
                            vm.stopRecording()
                        } else {
                            await vm.startRecording()
                        }
                    }
                } label: {
                    Image(systemName: vm.isRecording ? "mic.fill" : "mic")
                        .font(.system(size: 48))
                        .foregroundStyle(vm.isRecording ? .red : .blue)
                        .frame(width: 110, height: 110)
                        .background(
                            Circle().fill(
                                vm.isRecording
                                    ? Color.red.opacity(0.12)
                                    : Color.blue.opacity(0.12)
                            )
                        )
                }
            }

            // Example prompts
            VStack(alignment: .leading, spacing: 6) {
                Text("Example phrases:")
                    .font(.subheadline.bold())
                ForEach([
                    "\"Drove 45 minutes on the highway\"",
                    "\"One hour night driving with Sarah\"",
                    "\"30 minutes urban driving in the rain with Mum\"",
                    "\"An hour and a half rural driving with Dad\"",
                ], id: \.self) { example in
                    Text(example)
                        .font(.subheadline)
                        .italic()
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal)

            // Live transcript
            if !vm.transcript.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Label("Transcript", systemImage: "text.bubble.fill")
                        .font(.subheadline.bold())
                    Text(vm.transcript)
                        .font(.body)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal)
            }

            // Error
            if let err = vm.errorMessage {
                Label(err, systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            // Parsed result
            if let parsed = vm.parsedSession {
                parsedResultCard(parsed)
            }
        }
        .padding(.vertical, 24)
    }

    // MARK: - Timer Mode

    private var timerModeContent: some View {
        VStack(spacing: 32) {
            Spacer(minLength: 20)

            // Large clock display
            if vm.sessionInProgress {
                VStack(spacing: 8) {
                    Text(vm.sessionElapsedText)
                        .font(.system(size: 72, weight: .thin, design: .monospaced))
                        .foregroundStyle(.primary)
                    Text("Say \"stop driving\" to finish")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "timer")
                        .font(.system(size: 60))
                        .foregroundStyle(.blue.opacity(0.7))
                    Text("Say \"start driving\" to begin")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }

            // Mic button with pulse
            ZStack {
                if vm.isRecording {
                    Circle()
                        .fill(Color.red.opacity(0.12))
                        .frame(width: 140, height: 140)
                        .scaleEffect(vm.isRecording ? 1.25 : 1.0)
                        .animation(
                            .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                            value: vm.isRecording
                        )
                }

                Button {
                    Task {
                        if vm.isRecording {
                            vm.stopRecording()
                        } else {
                            await vm.startRecording()
                        }
                    }
                } label: {
                    Image(systemName: vm.isRecording ? "mic.fill" : "mic")
                        .font(.system(size: 48))
                        .foregroundStyle(vm.isRecording ? .red : .blue)
                        .frame(width: 110, height: 110)
                        .background(
                            Circle().fill(
                                vm.isRecording
                                    ? Color.red.opacity(0.12)
                                    : Color.blue.opacity(0.12)
                            )
                        )
                }
            }

            Text(vm.isRecording ? "Listening for commands…" : "Tap mic to activate voice control")
                .font(.caption)
                .foregroundStyle(.secondary)

            // Error
            if let err = vm.errorMessage {
                Label(err, systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(.red)
                    .padding(.horizontal)
            }

            // Parsed result after session ends
            if let parsed = vm.parsedSession {
                parsedResultCard(parsed)
            }

            Spacer(minLength: 20)
        }
        .padding(.vertical, 24)
    }

    // MARK: - Parsed Result Card

    private func parsedResultCard(_ parsed: VoiceLogManager.ParsedSession) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Detected Session", systemImage: "checkmark.circle.fill")
                .font(.subheadline.bold())
                .foregroundStyle(.green)

            Divider()

            LabeledContent("Duration") {
                Text(formatDuration(parsed.durationMinutes))
                    .fontWeight(.semibold)
            }
            LabeledContent("Conditions") {
                Text(parsed.conditions.map(\.rawValue).joined(separator: ", "))
                    .fontWeight(.semibold)
            }
            if !parsed.supervisor.isEmpty {
                LabeledContent("Supervisor") {
                    Text(parsed.supervisor).fontWeight(.semibold)
                }
            }

            Divider()

            Button {
                onConfirm(parsed)
                dismiss()
            } label: {
                Label("Use This Session", systemImage: "arrow.right.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button("Try Again") {
                vm.parsedSession = nil
                vm.sessionElapsedText = "00:00"
                Task { await vm.startRecording() }
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color.green.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.green.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal)
    }

    private func formatDuration(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        switch (h, m) {
        case (0, _): return "\(m) min"
        case (_, 0): return "\(h) hr"
        default:     return "\(h) hr \(m) min"
        }
    }
}
