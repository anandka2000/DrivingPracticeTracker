import SwiftUI

struct SessionDetailView: View {
    @EnvironmentObject var store: SessionStore
    @Environment(\.dismiss) private var dismiss

    // Use @State so edits are local until saved
    @State private var session: DrivingSession
    @State private var isEditing = false
    @State private var showDeleteConfirm = false

    init(session: DrivingSession) {
        _session = State(initialValue: session)
    }

    var body: some View {
        List {
            // Date & Duration
            Section("Session") {
                LabeledContent("Date") {
                    Text(session.date.formatted(date: .long, time: .shortened))
                        .multilineTextAlignment(.trailing)
                }
                LabeledContent("Duration", value: session.formattedDuration)
                LabeledContent("Hours", value: String(format: "%.2f", session.durationHours))
            }

            // Conditions
            Section("Conditions") {
                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible()), count: 3),
                    spacing: 8
                ) {
                    ForEach(DrivingCondition.allCases) { condition in
                        let active = session.conditions.contains(condition)
                        Label(condition.rawValue, systemImage: condition.sfSymbol)
                            .font(.caption.bold())
                            .padding(.vertical, 6)
                            .frame(maxWidth: .infinity)
                            .background(active ? Color.blue.opacity(0.15) : Color(.secondarySystemFill))
                            .foregroundStyle(active ? Color.blue : Color.secondary)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
                .padding(.vertical, 4)
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }

            if !session.supervisor.isEmpty {
                Section("Supervisor") {
                    Text(session.supervisor)
                }
            }

            if !session.notes.isEmpty {
                Section("Notes") {
                    Text(session.notes)
                }
            }

            // Delete
            Section {
                Button("Delete Session", role: .destructive) {
                    showDeleteConfirm = true
                }
            }
        }
        .navigationTitle("Session Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isEditing ? "Done" : "Edit") {
                    if isEditing { store.updateSession(session) }
                    isEditing.toggle()
                }
            }
        }
        .confirmationDialog(
            "Delete this session?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                store.deleteSession(session)
                dismiss()
            }
        }
    }
}
