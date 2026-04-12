import Foundation

struct RequirementsProfile: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var totalRequiredHours: Double
    var nightRequiredHours: Double
    var highwayRequiredHours: Double

    init(
        id: UUID = UUID(),
        name: String,
        totalRequiredHours: Double,
        nightRequiredHours: Double = 0,
        highwayRequiredHours: Double = 0
    ) {
        self.id = id
        self.name = name
        self.totalRequiredHours = totalRequiredHours
        self.nightRequiredHours = nightRequiredHours
        self.highwayRequiredHours = highwayRequiredHours
    }

    // Fixed UUIDs so presets remain stable across launches
    static let presets: [RequirementsProfile] = [
        RequirementsProfile(
            id: UUID(uuidString: "10000001-0000-0000-0000-000000000001")!,
            name: "NSW Australia", totalRequiredHours: 120, nightRequiredHours: 20),
        RequirementsProfile(
            id: UUID(uuidString: "10000001-0000-0000-0000-000000000002")!,
            name: "VIC Australia", totalRequiredHours: 120, nightRequiredHours: 10),
        RequirementsProfile(
            id: UUID(uuidString: "10000001-0000-0000-0000-000000000003")!,
            name: "QLD Australia", totalRequiredHours: 100, nightRequiredHours: 10),
        RequirementsProfile(
            id: UUID(uuidString: "10000001-0000-0000-0000-000000000004")!,
            name: "WA Australia",  totalRequiredHours: 50,  nightRequiredHours: 5),
        RequirementsProfile(
            id: UUID(uuidString: "10000001-0000-0000-0000-000000000005")!,
            name: "California USA", totalRequiredHours: 50, nightRequiredHours: 10),
        RequirementsProfile(
            id: UUID(uuidString: "10000001-0000-0000-0000-000000000006")!,
            name: "New York USA",  totalRequiredHours: 50,  nightRequiredHours: 15),
        RequirementsProfile(
            id: UUID(uuidString: "10000001-0000-0000-0000-000000000007")!,
            name: "UK (Recommended)", totalRequiredHours: 45, nightRequiredHours: 0),
        RequirementsProfile(
            id: UUID(uuidString: "10000001-0000-0000-0000-000000000008")!,
            name: "Custom", totalRequiredHours: 120, nightRequiredHours: 20),
    ]

    static var defaultProfile: RequirementsProfile { presets[0] }
}
