import Foundation

struct RequirementsProfile: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var region: String
    var totalRequiredHours: Double
    var nightRequiredHours: Double
    var highwayRequiredHours: Double

    init(
        id: UUID = UUID(),
        name: String,
        region: String = "",
        totalRequiredHours: Double,
        nightRequiredHours: Double = 0,
        highwayRequiredHours: Double = 0
    ) {
        self.id = id
        self.name = name
        self.region = region
        self.totalRequiredHours = totalRequiredHours
        self.nightRequiredHours = nightRequiredHours
        self.highwayRequiredHours = highwayRequiredHours
    }

    // CodingKeys for backward compat — region defaults to "" if missing from saved data
    enum CodingKeys: String, CodingKey {
        case id, name, region, totalRequiredHours, nightRequiredHours, highwayRequiredHours
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        region = (try? container.decode(String.self, forKey: .region)) ?? ""
        totalRequiredHours = try container.decode(Double.self, forKey: .totalRequiredHours)
        nightRequiredHours = try container.decode(Double.self, forKey: .nightRequiredHours)
        highwayRequiredHours = try container.decode(Double.self, forKey: .highwayRequiredHours)
    }

    // MARK: - Australia presets
    static let australiaProfiles: [RequirementsProfile] = [
        RequirementsProfile(
            id: UUID(uuidString: "10000001-0000-0000-0000-000000000001")!,
            name: "NSW", region: "New South Wales",
            totalRequiredHours: 120, nightRequiredHours: 20),
        RequirementsProfile(
            id: UUID(uuidString: "10000001-0000-0000-0000-000000000002")!,
            name: "VIC", region: "Victoria",
            totalRequiredHours: 120, nightRequiredHours: 10),
        RequirementsProfile(
            id: UUID(uuidString: "10000001-0000-0000-0000-000000000003")!,
            name: "QLD", region: "Queensland",
            totalRequiredHours: 100, nightRequiredHours: 10),
        RequirementsProfile(
            id: UUID(uuidString: "10000001-0000-0000-0000-000000000004")!,
            name: "WA", region: "Western Australia",
            totalRequiredHours: 50, nightRequiredHours: 5),
        RequirementsProfile(
            id: UUID(uuidString: "10000001-0000-0000-0000-000000000009")!,
            name: "SA", region: "South Australia",
            totalRequiredHours: 75, nightRequiredHours: 15),
        RequirementsProfile(
            id: UUID(uuidString: "10000001-0000-0000-0000-000000000010")!,
            name: "TAS", region: "Tasmania",
            totalRequiredHours: 80, nightRequiredHours: 0),
        RequirementsProfile(
            id: UUID(uuidString: "10000001-0000-0000-0000-000000000011")!,
            name: "ACT", region: "Australian Capital Territory",
            totalRequiredHours: 100, nightRequiredHours: 15),
        RequirementsProfile(
            id: UUID(uuidString: "10000001-0000-0000-0000-000000000012")!,
            name: "NT", region: "Northern Territory",
            totalRequiredHours: 50, nightRequiredHours: 0),
    ]

    // MARK: - USA presets
    static let usaProfiles: [RequirementsProfile] = [
        RequirementsProfile(
            id: UUID(uuidString: "10000001-0000-0000-0000-000000000005")!,
            name: "California", region: "California",
            totalRequiredHours: 50, nightRequiredHours: 10),
        RequirementsProfile(
            id: UUID(uuidString: "10000001-0000-0000-0000-000000000006")!,
            name: "New York", region: "New York",
            totalRequiredHours: 50, nightRequiredHours: 15),
        RequirementsProfile(
            id: UUID(uuidString: "10000001-0000-0000-0000-000000000013")!,
            name: "Texas", region: "Texas",
            totalRequiredHours: 30, nightRequiredHours: 0),
        RequirementsProfile(
            id: UUID(uuidString: "10000001-0000-0000-0000-000000000014")!,
            name: "Florida", region: "Florida",
            totalRequiredHours: 50, nightRequiredHours: 10),
        RequirementsProfile(
            id: UUID(uuidString: "10000001-0000-0000-0000-000000000015")!,
            name: "Illinois", region: "Illinois",
            totalRequiredHours: 50, nightRequiredHours: 10),
        RequirementsProfile(
            id: UUID(uuidString: "10000001-0000-0000-0000-000000000016")!,
            name: "Pennsylvania", region: "Pennsylvania",
            totalRequiredHours: 65, nightRequiredHours: 10),
        RequirementsProfile(
            id: UUID(uuidString: "10000001-0000-0000-0000-000000000017")!,
            name: "Ohio", region: "Ohio",
            totalRequiredHours: 24, nightRequiredHours: 0),
        RequirementsProfile(
            id: UUID(uuidString: "10000001-0000-0000-0000-000000000018")!,
            name: "Georgia", region: "Georgia",
            totalRequiredHours: 40, nightRequiredHours: 0),
        RequirementsProfile(
            id: UUID(uuidString: "10000001-0000-0000-0000-000000000019")!,
            name: "Michigan", region: "Michigan",
            totalRequiredHours: 50, nightRequiredHours: 0),
        RequirementsProfile(
            id: UUID(uuidString: "10000001-0000-0000-0000-000000000020")!,
            name: "New Jersey", region: "New Jersey",
            totalRequiredHours: 50, nightRequiredHours: 10),
        RequirementsProfile(
            id: UUID(uuidString: "10000001-0000-0000-0000-000000000021")!,
            name: "Washington", region: "Washington",
            totalRequiredHours: 50, nightRequiredHours: 10),
        RequirementsProfile(
            id: UUID(uuidString: "10000001-0000-0000-0000-000000000022")!,
            name: "Colorado", region: "Colorado",
            totalRequiredHours: 50, nightRequiredHours: 10),
        RequirementsProfile(
            id: UUID(uuidString: "10000001-0000-0000-0000-000000000023")!,
            name: "Arizona", region: "Arizona",
            totalRequiredHours: 30, nightRequiredHours: 0),
        RequirementsProfile(
            id: UUID(uuidString: "10000001-0000-0000-0000-000000000024")!,
            name: "Virginia", region: "Virginia",
            totalRequiredHours: 45, nightRequiredHours: 15),
    ]

    // MARK: - UK presets
    static let ukProfiles: [RequirementsProfile] = [
        RequirementsProfile(
            id: UUID(uuidString: "10000001-0000-0000-0000-000000000007")!,
            name: "England/Wales", region: "England & Wales",
            totalRequiredHours: 45, nightRequiredHours: 0),
        RequirementsProfile(
            id: UUID(uuidString: "10000001-0000-0000-0000-000000000025")!,
            name: "Scotland", region: "Scotland",
            totalRequiredHours: 40, nightRequiredHours: 0),
    ]

    // MARK: - Grouped presets
    static let presetGroups: [(country: String, profiles: [RequirementsProfile])] = [
        (country: "Australia", profiles: australiaProfiles),
        (country: "United States", profiles: usaProfiles),
        (country: "United Kingdom", profiles: ukProfiles),
    ]

    // Flat list kept for backwards compatibility
    static var presets: [RequirementsProfile] {
        australiaProfiles + usaProfiles + ukProfiles
    }

    static var defaultProfile: RequirementsProfile { australiaProfiles[0] }
}
