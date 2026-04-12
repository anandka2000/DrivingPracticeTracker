import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: SessionStore
    @State private var showingCustomEditor = false
    @State private var customProfile = RequirementsProfile.defaultProfile

    var body: some View {
        NavigationStack {
            Form {
                // Jurisdiction presets
                Section("Jurisdiction") {
                    ForEach(RequirementsProfile.presets) { preset in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(preset.name)
                                    .font(.body)
                                Text(requirementsSummary(preset))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if store.profile.id == preset.id {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                                    .fontWeight(.semibold)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if preset.name == "Custom" {
                                customProfile = store.profile.name == "Custom"
                                    ? store.profile
                                    : preset
                                showingCustomEditor = true
                            } else {
                                store.updateProfile(preset)
                            }
                        }
                    }
                }

                // Current requirements summary
                Section("Active Requirements") {
                    LabeledContent("Total Hours", value: String(format: "%.0f h", store.profile.totalRequiredHours))
                    if store.profile.nightRequiredHours > 0 {
                        LabeledContent("Night Hours", value: String(format: "%.0f h", store.profile.nightRequiredHours))
                    }
                    if store.profile.highwayRequiredHours > 0 {
                        LabeledContent("Highway Hours", value: String(format: "%.0f h", store.profile.highwayRequiredHours))
                    }
                }

                // Siri shortcuts hint
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Siri Shortcuts", systemImage: "waveform")
                            .font(.headline)
                        Text("You can log drives and check progress with Siri:")
                        Text("\"Log driving in Driving Tracker\"")
                            .italic()
                            .foregroundStyle(.secondary)
                        Text("\"Check driving progress in Driving Tracker\"")
                            .italic()
                            .foregroundStyle(.secondary)
                        Text("Find these shortcuts in the Shortcuts app or by asking Siri.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                // Data management
                Section("Data") {
                    NavigationLink("Export Sessions (CSV)") {
                        ExportView()
                    }
                }
            }
            .navigationTitle("Settings")
            .sheet(isPresented: $showingCustomEditor) {
                CustomProfileEditor(profile: $customProfile) { saved in
                    var p = saved
                    p.name = "Custom"
                    store.updateProfile(p)
                }
            }
        }
    }

    private func requirementsSummary(_ profile: RequirementsProfile) -> String {
        var parts = [String(format: "%.0f hrs total", profile.totalRequiredHours)]
        if profile.nightRequiredHours > 0 {
            parts.append(String(format: "%.0f night", profile.nightRequiredHours))
        }
        return parts.joined(separator: " · ")
    }
}

// MARK: - Custom Profile Editor

struct CustomProfileEditor: View {
    @Binding var profile: RequirementsProfile
    let onSave: (RequirementsProfile) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Total Hours Required") {
                    Stepper(
                        String(format: "%.0f hours", profile.totalRequiredHours),
                        value: $profile.totalRequiredHours,
                        in: 1...500, step: 5
                    )
                }
                Section("Night Hours Required") {
                    Stepper(
                        String(format: "%.0f hours", profile.nightRequiredHours),
                        value: $profile.nightRequiredHours,
                        in: 0...100, step: 1
                    )
                }
                Section("Highway Hours Required") {
                    Stepper(
                        String(format: "%.0f hours", profile.highwayRequiredHours),
                        value: $profile.highwayRequiredHours,
                        in: 0...100, step: 1
                    )
                }
            }
            .navigationTitle("Custom Requirements")
            .toolbar {
                ToolbarItem(placement: .topBarLeading)  { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { onSave(profile); dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Export View

struct ExportView: View {
    @EnvironmentObject var store: SessionStore
    @State private var csvText = ""

    var body: some View {
        ScrollView {
            Text(csvText)
                .font(.system(.caption, design: .monospaced))
                .padding()
                .textSelection(.enabled)
        }
        .navigationTitle("Export CSV")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(item: csvText, subject: Text("Driving Sessions"))
            }
        }
        .onAppear { csvText = buildCSV() }
    }

    private func buildCSV() -> String {
        var lines = ["Date,Duration (min),Hours,Conditions,Supervisor,Notes"]
        for s in store.sessions.sorted(by: { $0.date < $1.date }) {
            let conditions = s.conditions.map(\.rawValue).joined(separator: "|")
            let notes = s.notes.replacingOccurrences(of: ",", with: ";")
            lines.append(
                "\(s.date.ISO8601Format()),\(s.durationMinutes),\(String(format:"%.2f",s.durationHours)),\(conditions),\(s.supervisor),\(notes)"
            )
        }
        return lines.joined(separator: "\n")
    }
}
