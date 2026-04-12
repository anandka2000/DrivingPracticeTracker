import Foundation

enum DrivingCondition: String, Codable, CaseIterable, Identifiable {
    case day = "Day"
    case night = "Night"
    case rain = "Rain"
    case highway = "Highway"
    case urban = "Urban"
    case rural = "Rural"

    var id: String { rawValue }

    var sfSymbol: String {
        switch self {
        case .day:     return "sun.max.fill"
        case .night:   return "moon.stars.fill"
        case .rain:    return "cloud.rain.fill"
        case .highway: return "road.lanes"
        case .urban:   return "building.2.fill"
        case .rural:   return "tree.fill"
        }
    }

    var accentColor: String {
        switch self {
        case .day:     return "yellow"
        case .night:   return "indigo"
        case .rain:    return "blue"
        case .highway: return "green"
        case .urban:   return "orange"
        case .rural:   return "brown"
        }
    }
}

struct DrivingSession: Identifiable, Codable, Hashable {
    var id: UUID
    var date: Date
    var durationMinutes: Int
    var conditions: [DrivingCondition]
    var supervisor: String
    var notes: String

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        durationMinutes: Int,
        conditions: [DrivingCondition] = [.day],
        supervisor: String = "",
        notes: String = ""
    ) {
        self.id = id
        self.date = date
        self.durationMinutes = durationMinutes
        self.conditions = conditions
        self.supervisor = supervisor
        self.notes = notes
    }

    var durationHours: Double { Double(durationMinutes) / 60.0 }
    var isNight: Bool    { conditions.contains(.night) }
    var isHighway: Bool  { conditions.contains(.highway) }

    var formattedDuration: String {
        let h = durationMinutes / 60
        let m = durationMinutes % 60
        switch (h, m) {
        case (0, _): return "\(m)m"
        case (_, 0): return "\(h)h"
        default:     return "\(h)h \(m)m"
        }
    }
}
