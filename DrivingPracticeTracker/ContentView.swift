import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: SessionStore
    @StateObject private var autoDrive = AutoDriveManager.shared

    var body: some View {
        ZStack(alignment: .top) {
            TabView {
                DashboardView()
                    .tabItem { Label("Dashboard", systemImage: "chart.bar.fill") }

                LogSessionView()
                    .tabItem { Label("Log Drive", systemImage: "plus.circle.fill") }

                SessionListView()
                    .tabItem { Label("History", systemImage: "list.bullet.rectangle.portrait.fill") }

                SettingsView()
                    .tabItem { Label("Settings", systemImage: "gear") }
            }

            // ── Banner: "Driving detected — log it?" ──
            if autoDrive.showStartBanner {
                drivingDetectedBanner
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(response: 0.4, dampingFraction: 0.75), value: autoDrive.showStartBanner)
                    .zIndex(10)
            }

            // ── Persistent pill: session is in progress after user said yes ──
            if autoDrive.isDrivingConfirmed && autoDrive.isDriving {
                activeDrivePill
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(response: 0.4, dampingFraction: 0.75), value: autoDrive.isDrivingConfirmed)
                    .zIndex(9)
            }
        }
        .onAppear {
            if store.autoLoggingEnabled { autoDrive.startMonitoring() }
        }
        .onChange(of: store.autoLoggingEnabled) { _, enabled in
            enabled ? autoDrive.startMonitoring() : autoDrive.stopMonitoring()
        }
        .sheet(isPresented: $autoDrive.showEndPrompt) {
            DetectedSessionSheet(autoDrive: autoDrive, store: store)
        }
    }

    // MARK: - Driving detected banner (before user responds)

    private var drivingDetectedBanner: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "car.fill")
                    .font(.title3)
                    .foregroundStyle(.white)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Driving detected")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                    if autoDrive.isListeningForVoiceResponse {
                        Label("Listening for yes / no…", systemImage: "waveform")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.85))
                    } else {
                        Text("Log this session?")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                Spacer()
            }
            HStack(spacing: 12) {
                Button("Yes, log it") { autoDrive.userConfirmedDriveStart() }
                    .font(.caption.bold())
                    .padding(.horizontal, 14).padding(.vertical, 6)
                    .background(Color.white.opacity(0.25))
                    .clipShape(Capsule())
                    .foregroundStyle(.white)

                Button("Dismiss") { autoDrive.userDismissedDriveStart() }
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.blue.opacity(0.93))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.18), radius: 8, y: 4)
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    // MARK: - Active drive pill (after user confirmed, while still driving)

    private var activeDrivePill: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.green)
                .frame(width: 8, height: 8)
                .overlay(
                    Circle().stroke(Color.green.opacity(0.4), lineWidth: 4)
                        .scaleEffect(1.6)
                        .opacity(0.7)
                )
            Text("Driving — logging session")
                .font(.caption.bold())
                .foregroundStyle(.white)
            Spacer()
            Button("End Drive") { autoDrive.endDriveNow() }
                .font(.caption.bold())
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(Color.white.opacity(0.25))
                .clipShape(Capsule())
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.green.opacity(0.88))
        .clipShape(Capsule())
        .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}

// MARK: - Detected Session Sheet

struct DetectedSessionSheet: View {
    @ObservedObject var autoDrive: AutoDriveManager
    @ObservedObject var store: SessionStore
    @Environment(\.dismiss) private var dismiss
    @State private var supervisor = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            if let session = autoDrive.pendingSession {
                Form {
                    Section("Detected Drive") {
                        LabeledContent("Date",      value: session.date.formatted(date: .abbreviated, time: .shortened))
                        LabeledContent("Duration",  value: formatDuration(session.durationMinutes))
                        LabeledContent("Conditions", value: session.conditions.map(\.rawValue).joined(separator: ", "))
                    }
                    Section("Supervisor (optional)") {
                        TextField("Supervisor name", text: $supervisor)
                            .textContentType(.name)
                    }
                    Section("Notes (optional)") {
                        TextEditor(text: $notes).frame(minHeight: 60)
                    }
                }
                .navigationTitle("Auto-Detected Drive")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Discard") {
                            autoDrive.dismissEndPrompt()
                            dismiss()
                        }
                        .foregroundStyle(.red)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Save") {
                            if let detected = autoDrive.saveDetectedSession() {
                                store.addSession(DrivingSession(
                                    date: detected.date,
                                    durationMinutes: detected.durationMinutes,
                                    conditions: detected.conditions,
                                    supervisor: supervisor,
                                    notes: notes
                                ))
                            }
                            dismiss()
                        }
                        .fontWeight(.semibold)
                    }
                }
            } else {
                ProgressView().onAppear { dismiss() }
            }
        }
    }

    private func formatDuration(_ minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        switch (h, m) {
        case (0, _): return "\(m) min"
        case (_, 0): return "\(h) hr"
        default:     return "\(h) hr \(m) min"
        }
    }
}
