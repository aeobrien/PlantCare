import Foundation

enum Direction: String, CaseIterable, Codable {
    case north = "North"
    case northeast = "Northeast"
    case east = "East"
    case southeast = "Southeast"
    case south = "South"
    case southwest = "Southwest"
    case west = "West"
    case northwest = "Northwest"
}

enum LightType: String, CaseIterable, Codable {
    case direct = "Direct"
    case indirect = "Indirect"
    case low = "Low"
}

enum HumidityPreference: String, CaseIterable, Codable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
}

enum CareStepType: String, CaseIterable, Codable {
    case watering = "Watering"
    case misting = "Misting"
    case dusting = "Dusting"
    case rotation = "Rotation"
    case custom = "Custom"
    
    var systemImageName: String {
        switch self {
        case .watering:
            return "drop.fill"
        case .misting:
            return "cloud.drizzle.fill"
        case .dusting:
            return "paintbrush.fill"
        case .rotation:
            return "arrow.clockwise"
        case .custom:
            return "star.fill"
        }
    }
}

struct CareStep: Identifiable, Codable {
    var id: UUID = UUID()
    var type: CareStepType
    var customName: String?
    var instructions: String
    var frequencyDays: Int
    var lastCompletedDate: Date?
    var isEnabled: Bool = true
    
    var displayName: String {
        if type == .custom, let customName = customName {
            return customName
        }
        return type.rawValue
    }
    
    var nextDueDate: Date? {
        guard let lastCompleted = lastCompletedDate else { return Date() }
        return Calendar.current.date(byAdding: .day, value: frequencyDays, to: lastCompleted)
    }
    
    var isOverdue: Bool {
        guard let dueDate = nextDueDate else { return false }
        return Date() > dueDate
    }
    
    var daysSinceLastCompleted: Int? {
        guard let lastCompleted = lastCompletedDate else { return nil }
        return Calendar.current.dateComponents([.day], from: lastCompleted, to: Date()).day
    }
    
    var daysUntilDue: Int? {
        guard let dueDate = nextDueDate else { return nil }
        return Calendar.current.dateComponents([.day], from: Date(), to: dueDate).day
    }
}

struct Window: Identifiable, Codable {
    var id: UUID = UUID()
    var direction: Direction
    var notes: String?
}

struct Room: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var windows: [Window]
    var orderIndex: Int
}

enum ZoneAspect: String, CaseIterable, Codable {
    case open = "Open"
    case southWall = "South Wall"
    case northWall = "North Wall"
    case eastWall = "East Wall"
    case westWall = "West Wall"
}

enum SunPeriod: String, CaseIterable, Codable {
    case am = "AM"
    case pm = "PM"
    case all = "ALL"
}

enum WindExposure: String, CaseIterable, Codable {
    case sheltered = "Sheltered"
    case exposed = "Exposed"
}

enum SunHours: String, CaseIterable, Codable {
    case zeroToTwo = "0-2"
    case twoToFour = "2-4"
    case fourToSix = "4-6"
    case sixPlus = "6+"
}

struct Zone: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var aspect: ZoneAspect
    var sunPeriod: SunPeriod
    var wind: WindExposure
    var sunHours: SunHours?
    var orderIndex: Int
    
    var inferredSunHours: SunHours {
        if let sunHours = sunHours {
            return sunHours
        }
        
        switch (aspect, sunPeriod) {
        case (.southWall, .all):
            return .sixPlus
        case (.northWall, _):
            return .zeroToTwo
        case (.eastWall, .am):
            return .twoToFour
        case (.westWall, .pm):
            return .twoToFour
        case (.open, .all):
            return .sixPlus
        case (.open, _):
            return .fourToSix
        default:
            return .twoToFour
        }
    }
}

enum SpaceType {
    case indoor(Room)
    case outdoor(Zone)
}

enum SpacePlacementPreference: String, CaseIterable {
    case indoor = "Indoor"
    case outdoor = "Outdoor"
    case noPreference = "No Preference"
}

struct Plant: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var assignedRoomID: UUID?
    var assignedZoneID: UUID?
    var assignedWindowID: UUID?
    
    var preferredLightDirection: Direction
    var lightType: LightType
    var generalNotes: String
    var careSteps: [CareStep] = []
    var humidityPreference: HumidityPreference?
    
    var wateringStep: CareStep? {
        careSteps.first { $0.type == .watering }
    }
    
    var enabledCareSteps: [CareStep] {
        careSteps.filter { $0.isEnabled }
    }
    
    var overdueCareSteps: [CareStep] {
        enabledCareSteps.filter { $0.isOverdue }
    }
    
    var dueTodayCareSteps: [CareStep] {
        enabledCareSteps.filter { step in
            guard let dueDate = step.nextDueDate else { return false }
            return Calendar.current.isDate(dueDate, inSameDayAs: Date())
        }
    }
    
    var hasAnyOverdueCareSteps: Bool {
        !overdueCareSteps.isEmpty
    }
    
    var nextDueCareStep: CareStep? {
        enabledCareSteps
            .compactMap { step -> (CareStep, Date)? in
                guard let dueDate = step.nextDueDate else { return nil }
                return (step, dueDate)
            }
            .min { first, second in first.1 < second.1 }?.0
    }
    
    mutating func addCareStep(_ careStep: CareStep) {
        careSteps.append(careStep)
    }
    
    mutating func removeCareStep(withId id: UUID) {
        careSteps.removeAll { $0.id == id }
    }
    
    mutating func updateCareStep(_ updatedStep: CareStep) {
        if let index = careSteps.firstIndex(where: { $0.id == updatedStep.id }) {
            careSteps[index] = updatedStep
        }
    }
    
    mutating func markCareStepCompleted(withId id: UUID, date: Date = Date()) {
        if let index = careSteps.firstIndex(where: { $0.id == id }) {
            careSteps[index].lastCompletedDate = date
        }
    }
}

struct CareSession: Identifiable, Codable {
    var id: UUID = UUID()
    var date: Date = Date()
    var completedCareSteps: [CompletedCareStep] = []
    
    func isPlantCompleted(_ plantID: UUID) -> Bool {
        completedCareSteps.contains { $0.plantID == plantID }
    }
    
    func completedStepsForPlant(_ plantID: UUID) -> [CompletedCareStep] {
        completedCareSteps.filter { $0.plantID == plantID }
    }
    
    mutating func markCareStepCompleted(plantID: UUID, careStepID: UUID) {
        let completedStep = CompletedCareStep(plantID: plantID, careStepID: careStepID, completedDate: Date())
        completedCareSteps.append(completedStep)
    }
    
    mutating func unmarkCareStepCompleted(plantID: UUID, careStepID: UUID) {
        completedCareSteps.removeAll { $0.plantID == plantID && $0.careStepID == careStepID }
    }
}

struct CompletedCareStep: Identifiable, Codable {
    var id: UUID = UUID()
    var plantID: UUID
    var careStepID: UUID
    var completedDate: Date
}

struct AppSettings: Codable {
    var earlyWarningDays: Int = 2
    var customRoomOrder: [UUID] = []
    var openAIAPIKey: String = ""
    
    init() {}
}