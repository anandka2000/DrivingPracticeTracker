import AppIntents
import Foundation

struct GetDrivingProgressIntent: AppIntent {
    static var title: LocalizedStringResource = "Check Driving Progress"
    static var description = IntentDescription(
        "Get a summary of your driving practice progress toward test requirements.",
        categoryName: "Driving Practice"
    )

    @MainActor
    func perform() async throws -> some ProvidesDialog & ReturnsValue<String> {
        let store = SessionStore.shared
        let profile = store.profile

        var parts: [String] = []

        // Total hours
        parts.append(String(
            format: "%.1f of %.0f total hours logged (%.0f%% complete).",
            store.totalHours,
            profile.totalRequiredHours,
            store.totalProgress * 100
        ))

        // Night hours
        if profile.nightRequiredHours > 0 {
            parts.append(String(
                format: "%.1f of %.0f night hours logged.",
                store.nightHours,
                profile.nightRequiredHours
            ))
        }

        // Highway hours
        if profile.highwayRequiredHours > 0 {
            parts.append(String(
                format: "%.1f of %.0f highway hours logged.",
                store.highwayHours,
                profile.highwayRequiredHours
            ))
        }

        // Overall status
        if store.isComplete {
            parts.append("You've met all requirements and can book your driving test.")
        } else {
            parts.append(String(
                format: "%.1f hours still needed to qualify.",
                store.remainingHours
            ))
        }

        let summary = parts.joined(separator: " ")
        return .result(value: summary, dialog: IntentDialog(stringLiteral: summary))
    }
}
