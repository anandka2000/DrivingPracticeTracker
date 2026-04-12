import AppIntents

/// Registers App Shortcuts that appear in Spotlight and are invocable by Siri
/// without the user needing to set them up manually in the Shortcuts app.
struct DrivingTrackerShortcuts: AppShortcutsProvider {

    static var appShortcuts: [AppShortcut] {

        // --- Log a session ---
        AppShortcut(
            intent: LogDrivingSessionIntent(),
            phrases: [
                "Log driving in \(.applicationName)",
                "Record a driving session in \(.applicationName)",
                "Add driving time to \(.applicationName)",
                "I drove in \(.applicationName)",
                "Log practice in \(.applicationName)",
            ],
            shortTitle: "Log Drive",
            systemImageName: "car.fill"
        )

        // --- Check progress ---
        AppShortcut(
            intent: GetDrivingProgressIntent(),
            phrases: [
                "Check my driving progress in \(.applicationName)",
                "How many driving hours in \(.applicationName)",
                "My driving status in \(.applicationName)",
                "How close am I to my driving test in \(.applicationName)",
            ],
            shortTitle: "Check Progress",
            systemImageName: "chart.bar.fill"
        )
    }
}
