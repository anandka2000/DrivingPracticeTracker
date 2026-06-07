import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: SessionStore

    // MARK: - Picker state
    private let allCountries = ["Australia", "United States", "United Kingdom", "Custom"]

    @State private var selectedCountry  = "Australia"
    @State private var selectedPresetID: UUID? = nil
    @State private var customProfile    = RequirementsProfile(
        name: "Custom", totalRequiredHours: 50, nightRequiredHours: 10
    )

    var body: some View {
        NavigationStack {
            Form {

                // MARK: Auto Logging
                Section("Auto Logging") {
                    Toggle("Detect & auto-log drives", isOn: $store.autoLoggingEnabled)
                }

                // MARK: Jurisdiction — cascading pickers
                Section("Jurisdiction") {

                    // Country / Custom picker
                    Picker("Country", selection: countryBinding) {
                        ForEach(allCountries, id: \.self) { Text($0).tag($0) }
                    }
                    .pickerStyle(.menu)

                    // State / region picker — only shown for preset countries
                    if selectedCountry != "Custom" {
                        Picker("State / Region", selection: presetBinding) {
                            ForEach(presetsFor(selectedCountry)) { preset in
                                Text(preset.region.isEmpty ? preset.name : preset.region)
                                    .tag(Optional(preset.id))
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                // MARK: Custom Profile — inline, only when "Custom" is selected
                if selectedCountry == "Custom" {
                    Section("Custom Profile") {
                        TextField("Name / Region (optional)", text: $customProfile.region)
                            .onChange(of: customProfile.region) { _, _ in applyCustom() }

                        Stepper(
                            "Total: \(Int(customProfile.totalRequiredHours)) hours",
                            value: $customProfile.totalRequiredHours, in: 1...500, step: 5
                        )
                        .onChange(of: customProfile.totalRequiredHours) { _, _ in applyCustom() }

                        Stepper(
                            "Night: \(Int(customProfile.nightRequiredHours)) hours",
                            value: $customProfile.nightRequiredHours, in: 0...100, step: 1
                        )
                        .onChange(of: customProfile.nightRequiredHours) { _, _ in applyCustom() }

                        Stepper(
                            "Highway: \(Int(customProfile.highwayRequiredHours)) hours",
                            value: $customProfile.highwayRequiredHours, in: 0...100, step: 1
                        )
                        .onChange(of: customProfile.highwayRequiredHours) { _, _ in applyCustom() }
                    }
                }

                // MARK: Active Requirements — live summary
                Section("Active Requirements") {
                    LabeledContent("Jurisdiction", value: store.profile.name)
                    if !store.profile.region.isEmpty {
                        LabeledContent("Region", value: store.profile.region)
                    }
                    LabeledContent("Total Hours",
                                   value: String(format: "%.0f h", store.profile.totalRequiredHours))
                    if store.profile.nightRequiredHours > 0 {
                        LabeledContent("Night Hours",
                                       value: String(format: "%.0f h", store.profile.nightRequiredHours))
                    }
                    if store.profile.highwayRequiredHours > 0 {
                        LabeledContent("Highway Hours",
                                       value: String(format: "%.0f h", store.profile.highwayRequiredHours))
                    }
                }

                // MARK: Siri Shortcuts hint
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Siri Shortcuts", systemImage: "waveform")
                            .font(.headline)
                        Text("You can log drives and check progress with Siri:")
                        Text("\"Log driving in SteerStart\"")
                            .italic()
                            .foregroundStyle(.secondary)
                        Text("\"Check driving progress in SteerStart\"")
                            .italic()
                            .foregroundStyle(.secondary)
                        Text("Find these shortcuts in the Shortcuts app or by asking Siri.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                // MARK: Data / Export
                Section("Data") {
                    NavigationLink {
                        ReportView()
                    } label: {
                        Label("Report & Export (PDF / CSV)", systemImage: "doc.richtext")
                    }
                }
            }
            .navigationTitle("Settings")
            .onAppear { syncFromStore() }
        }
    }

    // MARK: - Custom Bindings (prevent onChange firing during programmatic sync)

    /// Binding for the country picker — calls side-effects only on user interaction.
    private var countryBinding: Binding<String> {
        Binding(
            get: { selectedCountry },
            set: { newCountry in
                selectedCountry = newCountry
                onCountryChange(newCountry)
            }
        )
    }

    /// Binding for the preset picker — applies the chosen preset to the store.
    private var presetBinding: Binding<UUID?> {
        Binding(
            get: { selectedPresetID },
            set: { newID in
                selectedPresetID = newID
                if let id = newID,
                   let preset = RequirementsProfile.presets.first(where: { $0.id == id }) {
                    store.updateProfile(preset)
                }
            }
        )
    }

    // MARK: - Helpers

    private func presetsFor(_ country: String) -> [RequirementsProfile] {
        RequirementsProfile.presetGroups.first(where: { $0.country == country })?.profiles ?? []
    }

    /// Sync picker selections to match the currently active profile in the store.
    /// Called once on appear — does NOT go through the custom Bindings so no side-effects fire.
    private func syncFromStore() {
        // Always restore the saved custom profile into local state
        customProfile = store.savedCustomProfile

        if store.profile.name == "Custom" {
            selectedCountry = "Custom"
            customProfile   = store.profile   // use the live custom values
            return
        }

        for group in RequirementsProfile.presetGroups {
            if group.profiles.contains(where: { $0.id == store.profile.id }) {
                selectedCountry  = group.country
                selectedPresetID = store.profile.id
                return
            }
        }
        // Fallback: first Australian preset
        selectedCountry  = "Australia"
        selectedPresetID = RequirementsProfile.australiaProfiles.first?.id
    }

    /// Called when the user changes the country picker.
    private func onCountryChange(_ country: String) {
        if country == "Custom" {
            // Restore the last-saved custom profile so values are preserved
            customProfile = store.savedCustomProfile
            applyCustom()
        } else {
            // If the active preset is already in this country, keep it selected;
            // otherwise default to the first preset in the new country.
            let presets = presetsFor(country)
            if let existing = presets.first(where: { $0.id == selectedPresetID }),
               presets.contains(where: { $0.id == existing.id }) {
                store.updateProfile(existing)
            } else if let first = presets.first {
                selectedPresetID = first.id
                store.updateProfile(first)
            }
        }
    }

    /// Persist the current custom profile and make it the active profile.
    private func applyCustom() {
        var p = customProfile
        p.name = "Custom"
        store.saveCustomProfile(p)  // saves to store.savedCustomProfile + UserDefaults
        store.updateProfile(p)      // makes it the active profile
    }
}
