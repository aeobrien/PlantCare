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

struct Plant: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var assignedRoomID: UUID?
    var assignedWindowID: UUID?
    
    var preferredLightDirection: Direction
    var lightType: LightType
    var wateringInstructions: String
    var generalNotes: String
    
    var lastWateredDate: Date?
    var wateringFrequencyDays: Int?
    var humidityPreference: HumidityPreference?
    var rotationFrequency: String?
}

struct CareSession: Identifiable, Codable {
    var id: UUID = UUID()
    var date: Date = Date()
    var completedPlantIDs: Set<UUID> = []
}