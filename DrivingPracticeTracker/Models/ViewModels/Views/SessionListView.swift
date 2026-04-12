import SwiftUI

struct SessionListView: View {
    @EnvironmentObject var store: SessionStore
    @State private var searchText = ""
    @State private var filterNight = false

    private var filteredSessions: [DrivingSession] {
        store.sessions
            .filter { session in
                let matchesSearch = searchText.isEmpty
                    || session.supervisor.localizedCaseInsensitiveContains(searchText)
                    || session.notes.localizedCaseInsensitiveContains(searchText)
                let matchesNight = !filterNight || session.isNight
                return matchesSearch && matchesNight
            }
    }

    var body: some View {
        NavigationStack {
            List {
                // Summary header row
                if !store.sessions.isEmpty {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(format: "%.1f hrs total", store.totalHours))
                                .font(.headline)
                            Text("\(store.sessionCount) session\(store.sessionCount == 1 ? "" : "s")")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("Night only", isOn: $filterNight)
                            .font(.caption)
                            .toggleStyle(.button)
                            .tint(.indigo)
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 4, trailing: 16))
                }

                ForEach(filteredSessions) { session in
                    NavigationLink(destination: SessionDetailView(session: session)) {
                        SessionRowContent(session: session)
                    }
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                .onDelete(perform: deleteItems)
            }
            .listStyle(.plain)
            .navigationTitle("History")
            .searchable(text: $searchText, prompt: "Search by supervisor or notes")
            .overlay {
                if store.sessions.isEmpty {
                    ContentUnavailableView(
                        "No Sessions Yet",
                        systemImage: "car.fill",
                        description: Text("Tap Log Drive to record your first session.")
                    )
                } else if filteredSessions.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
        }
    }

    private func deleteItems(at offsets: IndexSet) {
        // Map filtered offsets back to store indices
        let toDelete = offsets.map { filteredSessions[$0] }
        toDelete.forEach { store.deleteSession($0) }
    }
}

// Thin wrapper so the row style can be reused without NavigationLink chrome
struct SessionRowContent: View {
    let session: DrivingSession

    var body: some View {
        HStack {
            // Condition indicator strip
            RoundedRectangle(cornerRadius: 3)
                .fill(session.isNight ? Color.indigo : Color.yellow)
                .frame(width: 4)
                .padding(.vertical, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(session.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.subheadline.bold())
                HStack(spacing: 6) {
                    ForEach(session.conditions) { cond in
                        Label(cond.rawValue, systemImage: cond.sfSymbol)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .labelStyle(.iconOnly)
                    }
                    if !session.supervisor.isEmpty {
                        Text("· \(session.supervisor)")
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
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
