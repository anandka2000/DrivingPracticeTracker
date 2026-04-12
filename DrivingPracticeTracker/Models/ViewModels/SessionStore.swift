import Foundation
import Combine
import SwiftUI

/// Central data store for all driving sessions and requirements profile.
/// Exposed as a singleton so App Intents can access it without SwiftUI context.
class SessionStore: ObservableObject {
    static let shared = SessionStore()

    @Published var sessions: [DrivingSession] = []
    @Published var profile: RequirementsProfile = RequirementsProfile.defaultProfile

    private let fileManager = FileManager.default

    private var sessionsURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("sessions.json")
    }

    private var profileURL: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("profile.json")
    }

    private init() {
        loadSessions()
        loadProfile()
    }

    // MARK: - Computed statistics

    var totalHours: Double {
        sessions.reduce(0) { $0 + $1.durationHours }
    }

    var nightHours: Double {
        sessions.filter(\.isNight).reduce(0) { $0 + $1.durationHours }
    }

    var highwayHours: Double {
        sessions.filter(\.isHighway).reduce(0) { $0 + $1.durationHours }
    }

    var totalProgress: Double  { min(totalHours   / max(profile.totalRequiredHours,   1), 1.0) }
    var nightProgress: Double  { min(nightHours   / max(profile.nightRequiredHours,   1), 1.0) }
    var highwayProgress: Double { min(highwayHours / max(profile.highwayRequiredHours, 1), 1.0) }

    var remainingHours: Double      { max(profile.totalRequiredHours   - totalHours,   0) }
    var remainingNightHours: Double { max(profile.nightRequiredHours   - nightHours,   0) }

    var sessionCount: Int { sessions.count }

    var recentSessions: [DrivingSession] {
        Array(sessions.prefix(5))
    }

    var isComplete: Bool {
        totalHours >= profile.totalRequiredHours &&
        (profile.nightRequiredHours == 0 || nightHours >= profile.nightRequiredHours)
    }

    // MARK: - CRUD

    func addSession(_ session: DrivingSession) {
        sessions.insert(session, at: 0)
        sessions.sort { $0.date > $1.date }
        saveSessions()
    }

    func updateSession(_ session: DrivingSession) {
        guard let idx = sessions.firstIndex(where: { $0.id == session.id }) else { return }
        sessions[idx] = session
        sessions.sort { $0.date > $1.date }
        saveSessions()
    }

    func deleteSession(_ session: DrivingSession) {
        sessions.removeAll { $0.id == session.id }
        saveSessions()
    }

    func deleteSessions(at offsets: IndexSet) {
        sessions.remove(atOffsets: offsets)
        saveSessions()
    }

    func updateProfile(_ newProfile: RequirementsProfile) {
        profile = newProfile
        saveProfile()
    }

    // MARK: - Persistence

    private func saveSessions() {
        guard let data = try? JSONEncoder().encode(sessions) else { return }
        try? data.write(to: sessionsURL, options: .atomic)
    }

    private func loadSessions() {
        guard let data = try? Data(contentsOf: sessionsURL),
              let decoded = try? JSONDecoder().decode([DrivingSession].self, from: data) else { return }
        sessions = decoded.sorted { $0.date > $1.date }
    }

    private func saveProfile() {
        guard let data = try? JSONEncoder().encode(profile) else { return }
        try? data.write(to: profileURL, options: .atomic)
    }

    private func loadProfile() {
        guard let data = try? Data(contentsOf: profileURL),
              let decoded = try? JSONDecoder().decode(RequirementsProfile.self, from: data) else { return }
        profile = decoded
    }
}
