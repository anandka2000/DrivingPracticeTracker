import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: SessionStore
    @StateObject private var autoDrive = AutoDriveManager.shared

    var body: some View {
        ZStack(alignment: .top) {
            TabView {
                DashboardView()
                    .tabItem {
                        Label("Dashboard", systemImage: "chart.bar.fill")
                    }

                LogSessionView()
                    .tabItem {
                        Label("Log Drive", systemImage: "plus.circle.fill")
                    }

                SessionListView()
                    .tabItem {
                        Label("History", systemImage: "list.bullet.rectangle.portrait.fill")
                    }

                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gear")
                    }
            }

            // Driving detected banner
            if autoDrive.showStartBanner {
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Image(systemName: "car.fill")
                            .font(.title3)
                            .foregroundStyle(.white)
                        Text("Driving detected — logging this session?")
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    HStack(spacing: 12) {
                        Button("Yes, log it") {
                            autoDrive.userConfirmedDriveStart()
                        }
                        .font(.caption.bold())
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.25))
                        .clipShape(Capsule())
                        .foregroundStyle(.white)

                        Button("Dismiss") {
                            autoDrive.userDismissedDriveStart()
                        }
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.8))

                        Spacer()
                    }
                    .padding(.top, 6)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.blue.opacity(0.92))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.spring(response: 0.4, dampingFraction: 0.75), value: autoDrive.showStartBanner)
                .zIndex(1)
            }
        }
        .onAppear {
            if store.autoLoggingEnabled {
                autoDrive.startMonitoring()
            }
        }
        .onChange(of: store.autoLoggingEnabled) { _, enabled in
            if enabled {
                autoDrive.startMonitoring()
            } else {
                autoDrive.stopMonitoring()
            }
        }
        .sheet(isPresented: $autoDrive.showEndPrompt) {
            DetectedSessionSheet(autoDrive: autoDrive, store: store)
        }
    }
}

// MARK: - Detected Session Sheet

struct DetectedSessionSheet: View {
    @ObservedObject var autoDrive: AutoDriveManager
    @ObservedObject var store: SessionStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            if let session = autoDrive.pendingSession {
                Form {
                    Section("Detected Drive") {
                        LabeledContent("Date", value: session.date.formatted(date: .abbreviated, time: .shortened))
                        LabeledContent("Duration", value: formatDuration(session.durationMinutes))
                        LabeledContent("Conditions", value: session.conditions.map(\.rawValue).joined(separator: ", "))
                    }
                }
                .navigationTitle("Auto-Detected Session")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Dismiss") {
                            autoDrive.dismissEndPrompt()
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Save") {
                            if let detected = autoDrive.saveDetectedSession() {
                                let newSession = DrivingSession(
                                    date: detected.date,
                                    durationMinutes: detected.durationMinutes,
                                    conditions: detected.conditions
                                )
                                store.addSession(newSession)
                            }
                            dismiss()
                        }
                        .fontWeight(.semibold)
                    }
                }
            } else {
                ProgressView()
                    .onAppear { dismiss() }
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
