import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var store: SessionStore
    @State private var showNameEditor = false
    @State private var pendingName = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Driver greeting
                    HStack {
                        if store.driverName.isEmpty {
                            Button("Set your name") { showNameEditor = true }
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Hi, \(store.driverName)! 👋")
                                .font(.title3.bold())
                            Spacer()
                            Button {
                                pendingName = store.driverName
                                showNameEditor = true
                            } label: {
                                Image(systemName: "pencil.circle")
                                    .font(.title3)
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Completion banner
                    if store.isComplete {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.title2)
                            Text("All requirements met! Ready to book your test.")
                                .font(.subheadline.bold())
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green.opacity(0.15))
                        .foregroundStyle(.green)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal)
                    }

                    // Progress rings
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Progress")
                            .font(.title2.bold())
                            .padding(.horizontal)

                        HStack(spacing: 20) {
                            Spacer()
                            ProgressRingView(
                                progress: store.totalProgress,
                                title: "Total",
                                current: store.totalHours,
                                required: store.profile.totalRequiredHours,
                                color: .blue
                            )

                            if store.profile.nightRequiredHours > 0 {
                                ProgressRingView(
                                    progress: store.nightProgress,
                                    title: "Night",
                                    current: store.nightHours,
                                    required: store.profile.nightRequiredHours,
                                    color: .indigo
                                )
                            }

                            if store.profile.highwayRequiredHours > 0 {
                                ProgressRingView(
                                    progress: store.highwayProgress,
                                    title: "Highway",
                                    current: store.highwayHours,
                                    required: store.profile.highwayRequiredHours,
                                    color: .green
                                )
                            }
                            Spacer()
                        }
                    }

                    // Quick stats
                    HStack(spacing: 12) {
                        StatCard(
                            title: "Sessions",
                            value: "\(store.sessionCount)",
                            icon: "car.fill",
                            color: .blue
                        )
                        StatCard(
                            title: "Remaining",
                            value: String(format: "%.1fh", store.remainingHours),
                            icon: "clock.fill",
                            color: .orange
                        )
                    }
                    .padding(.horizontal)

                    if store.profile.nightRequiredHours > 0 {
                        HStack(spacing: 12) {
                            StatCard(
                                title: "Night Logged",
                                value: String(format: "%.1fh", store.nightHours),
                                icon: "moon.stars.fill",
                                color: .indigo
                            )
                            StatCard(
                                title: "Night Remaining",
                                value: String(format: "%.1fh", store.remainingNightHours),
                                icon: "moon.fill",
                                color: .purple
                            )
                        }
                        .padding(.horizontal)
                    }

                    // Recent sessions
                    if !store.recentSessions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Recent Sessions")
                                    .font(.title2.bold())
                                Spacer()
                                NavigationLink("See All") {
                                    SessionListView()
                                }
                                .font(.subheadline)
                            }
                            .padding(.horizontal)

                            ForEach(store.recentSessions) { session in
                                NavigationLink(destination: SessionDetailView(session: session)) {
                                    SessionRowView(session: session)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle(store.profile.name)
            .navigationBarTitleDisplayMode(.large)
            .alert("Your Name", isPresented: $showNameEditor) {
                TextField("Enter your name", text: $pendingName)
                Button("Save") {
                    store.driverName = pendingName.trimmingCharacters(in: .whitespaces)
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This appears as a greeting on the dashboard.")
            }
            .onAppear {
                pendingName = store.driverName
            }
        }
    }
}

// MARK: - Progress Ring

struct ProgressRingView: View {
    let progress: Double
    let title: String
    let current: Double
    let required: Double
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: min(CGFloat(progress), 1.0))
                    .stroke(color, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.6), value: progress)

                VStack(spacing: 2) {
                    Text(String(format: "%.0f%%", progress * 100))
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                    Text(String(format: "%.1fh", current))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 90, height: 90)

            Text(title)
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            Text(String(format: "/ %.0fh req.", required))
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 38, height: 38)
                .background(color.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.title3.bold())
            }
            Spacer()
        }
        .padding(12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Session Row (shared by Dashboard + History)

struct SessionRowView: View {
    let session: DrivingSession

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline.bold())
                HStack(spacing: 6) {
                    ForEach(session.conditions) { cond in
                        Image(systemName: cond.sfSymbol)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if !session.supervisor.isEmpty {
                        Text("with \(session.supervisor)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Spacer()
            Text(session.formattedDuration)
                .font(.subheadline.bold())
                .foregroundStyle(.blue)
        }
        .padding()
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
    }
}
