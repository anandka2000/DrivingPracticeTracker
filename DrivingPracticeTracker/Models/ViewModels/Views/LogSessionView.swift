import SwiftUI

struct LogSessionView: View {
    @EnvironmentObject var store: SessionStore
    @Environment(\.dismiss) private var dismiss

    @State private var date = Date()
    @State private var durationHours = 0
    @State private var durationMinutes = 30
    @State private var selectedConditions: Set<DrivingCondition> = [.day]
    @State private var supervisor = ""
    @State private var notes = ""
    @State private var showingVoiceLog = false
    @State private var showingConfirmation = false

    private var totalMinutes: Int { durationHours * 60 + durationMinutes }

    var body: some View {
        NavigationStack {
            Form {
                Section("Session Details") {
                    DatePicker("Date & Time", selection: $date, displayedComponents: [.date, .hourAndMinute])

                    HStack(spacing: 0) {
                        Text("Duration")
                        Spacer()
                        Picker("Hours", selection: $durationHours) {
                            ForEach(0..<10) { h in
                                Text("\(h) hr").tag(h)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 80)
                        .clipped()

                        Picker("Minutes", selection: $durationMinutes) {
                            ForEach([0, 5, 10, 15, 20, 25, 30, 35, 40, 45, 50, 55], id: \.self) { m in
                                Text("\(m) min").tag(m)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 90)
                        .clipped()
                    }
                    .frame(height: 100)
                }

                Section("Conditions") {
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible()), count: 3),
                        spacing: 10
                    ) {
                        ForEach(DrivingCondition.allCases) { condition in
                            ConditionToggleButton(
                                condition: condition,
                                isSelected: selectedConditions.contains(condition)
                            ) {
                                toggleCondition(condition)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                }

                Section("Supervisor (optional)") {
                    TextField("Supervisor name", text: $supervisor)
                        .textContentType(.name)
                }

                Section("Notes (optional)") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 80)
                }

                Section {
                    Button(action: saveSession) {
                        HStack {
                            Spacer()
                            Label("Save Session", systemImage: "checkmark.circle.fill")
                                .font(.headline)
                            Spacer()
                        }
                    }
                    .disabled(totalMinutes == 0)
                }
            }
            .navigationTitle("Log Drive")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingVoiceLog = true
                    } label: {
                        Image(systemName: "mic.fill")
                            .accessibilityLabel("Voice Log")
                    }
                }
            }
            .sheet(isPresented: $showingVoiceLog) {
                VoiceLogView { parsed in
                    applyParsed(parsed)
                }
            }
            .alert("Session Saved", isPresented: $showingConfirmation) {
                Button("OK") { }
            } message: {
                Text("Your \(totalMinutes < 60 ? "\(totalMinutes)min" : String(format: "%.1fh", Double(totalMinutes)/60)) drive has been logged.")
            }
        }
    }

    // MARK: - Actions

    private func toggleCondition(_ condition: DrivingCondition) {
        if selectedConditions.contains(condition) {
            guard selectedConditions.count > 1 else { return } // keep at least one
            selectedConditions.remove(condition)
        } else {
            // Day/Night are mutually exclusive
            if condition == .night { selectedConditions.remove(.day) }
            if condition == .day   { selectedConditions.remove(.night) }
            selectedConditions.insert(condition)
        }
    }

    private func saveSession() {
        guard totalMinutes > 0 else { return }
        store.addSession(DrivingSession(
            date: date,
            durationMinutes: totalMinutes,
            conditions: Array(selectedConditions),
            supervisor: supervisor,
            notes: notes
        ))
        resetForm()
        showingConfirmation = true
    }

    private func resetForm() {
        date = Date()
        durationHours = 0
        durationMinutes = 30
        selectedConditions = [.day]
        supervisor = ""
        notes = ""
    }

    func applyParsed(_ parsed: VoiceLogManager.ParsedSession) {
        durationHours   = parsed.durationMinutes / 60
        durationMinutes = parsed.durationMinutes % 60
        // snap minutes to nearest 5
        durationMinutes = (durationMinutes / 5) * 5
        selectedConditions = Set(parsed.conditions)
        if !parsed.supervisor.isEmpty { supervisor = parsed.supervisor }
    }
}

// MARK: - Condition Toggle Button

struct ConditionToggleButton: View {
    let condition: DrivingCondition
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: condition.sfSymbol)
                    .font(.title2)
                Text(condition.rawValue)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? Color.blue.opacity(0.18) : Color(.secondarySystemFill))
            .foregroundStyle(isSelected ? Color.blue : Color.secondary)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}
