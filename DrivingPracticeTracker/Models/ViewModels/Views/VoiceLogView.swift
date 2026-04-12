import SwiftUI

struct VoiceLogView: View {
    @StateObject private var vm = VoiceLogManager()
    @Environment(\.dismiss) private var dismiss
    let onConfirm: (VoiceLogManager.ParsedSession) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
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
                }
                .padding(.vertical, 24)
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
