@preconcurrency import AppIntents
import Foundation

// MARK: - DrivingCondition AppEnum

extension DrivingCondition: AppEnum {
    nonisolated static var typeDisplayRepresentation: TypeDisplayRepresentation { "Driving Condition" }
    nonisolated static var caseDisplayRepresentations: [DrivingCondition: DisplayRepresentation] {
        [
            .day:     DisplayRepresentation(title: "Day",     image: .init(systemName: "sun.max.fill")),
            .night:   DisplayRepresentation(title: "Night",   image: .init(systemName: "moon.stars.fill")),
            .rain:    DisplayRepresentation(title: "Rain",    image: .init(systemName: "cloud.rain.fill")),
            .highway: DisplayRepresentation(title: "Highway", image: .init(systemName: "road.lanes")),
            .urban:   DisplayRepresentation(title: "Urban",   image: .init(systemName: "building.2.fill")),
            .rural:   DisplayRepresentation(title: "Rural",   image: .init(systemName: "tree.fill")),
        ]
    }
}

// MARK: - Log Driving Session Intent

struct LogDrivingSessionIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Driving Session"
    static var description = IntentDescription(
        "Record a driving practice session with duration and conditions.",
        categoryName: "Driving Practice"
    )

    // Parameters shown to Siri / Shortcuts
    @Parameter(
        title: "Duration (minutes)",
        description: "How many minutes did you drive?",
        requestValueDialog: "How many minutes was the drive?"
    )
    var durationMinutes: Int

    @Parameter(
        title: "Night driving?",
        description: "Was this a night drive?",
        default: false
    )
    var isNight: Bool

    @Parameter(
        title: "Highway driving?",
        description: "Did you drive on a highway or motorway?",
        default: false
    )
    var isHighway: Bool

    @Parameter(
        title: "Rainy conditions?",
        description: "Was it raining?",
        default: false
    )
    var isRaining: Bool

    @Parameter(
        title: "Supervisor name",
        description: "Who supervised the session?",
        requestValueDialog: "What's the supervisor's name?"
    )
    var supervisor: String?

    // Siri parameter summary line
    static var parameterSummary: some ParameterSummary {
        Summary("Log \(\.$durationMinutes) min driving session") {
            \.$isNight
            \.$isHighway
            \.$isRaining
            \.$supervisor
        }
    }

    @MainActor
    func perform() async throws -> some ProvidesDialog & ReturnsValue<String> {
        var conditions: [DrivingCondition] = [isNight ? .night : .day]
        if isHighway  { conditions.append(.highway) }
        if isRaining  { conditions.append(.rain) }

        let session = DrivingSession(
            durationMinutes: durationMinutes,
            conditions: conditions,
            supervisor: supervisor ?? ""
        )

        SessionStore.shared.addSession(session)

        let total     = SessionStore.shared.totalHours
        let remaining = SessionStore.shared.remainingHours

        let response: String
        if remaining <= 0 {
            response = String(
                format: "Logged %d minutes. You've completed all %.0f required hours — time to book your test!",
                durationMinutes,
                SessionStore.shared.profile.totalRequiredHours
            )
        } else {
            response = String(
                format: "Logged %d minutes of %@driving. Total: %.1f hours. %.1f hours still to go.",
                durationMinutes,
                isNight ? "night " : "",
                total,
                remaining
            )
        }

        return .result(value: response, dialog: IntentDialog(stringLiteral: response))
    }
}
