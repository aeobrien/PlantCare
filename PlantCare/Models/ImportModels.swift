import Foundation

struct ImportedPlant: Codable {
    let name: String
    let room: String
    let windowDirection: String
    let preferredLightDirection: String
    let lightType: String
    let wateringInstructions: String
    let careNotes: String
}

struct RoomMapping {
    let unmatchedRoom: String
    var matchedRoomID: UUID?
    var createNew: Bool = false
}

extension ImportedPlant {
    func toPlant(roomID: UUID?, windowID: UUID?) -> Plant {
        let lightTypeEnum: LightType = {
            switch lightType.lowercased() {
            case "direct": return .direct
            case "indirect": return .indirect
            case "low": return .low
            default: return .indirect
            }
        }()
        
        let preferredDirection: Direction = {
            switch preferredLightDirection.lowercased() {
            case "north": return .north
            case "northeast", "east or northeast": return .northeast
            case "east", "east or southeast": return .east
            case "southeast": return .southeast
            case "south", "south or west", "south or southeast": return .south
            case "southwest", "southeast or southwest": return .southwest
            case "west": return .west
            case "northwest": return .northwest
            default: return .east
            }
        }()
        
        return Plant(
            name: name,
            assignedRoomID: roomID,
            assignedWindowID: windowID,
            preferredLightDirection: preferredDirection,
            lightType: lightTypeEnum,
            wateringInstructions: wateringInstructions,
            generalNotes: careNotes,
            lastWateredDate: nil,
            wateringFrequencyDays: estimateWateringFrequency(),
            humidityPreference: estimateHumidityPreference(),
            rotationFrequency: extractRotationFrequency()
        )
    }
    
    private func estimateWateringFrequency() -> Int {
        let instructions = wateringInstructions.lowercased()
        if instructions.contains("daily") { return 1 }
        if instructions.contains("every other day") { return 2 }
        if instructions.contains("twice a week") { return 3 }
        if instructions.contains("weekly") || instructions.contains("once a week") { return 7 }
        if instructions.contains("every 2 weeks") || instructions.contains("every two weeks") { return 14 }
        if instructions.contains("every 3 weeks") || instructions.contains("every three weeks") { return 21 }
        if instructions.contains("monthly") || instructions.contains("once a month") { return 30 }
        
        // Default based on light type
        switch lightType.lowercased() {
        case "direct": return 7
        case "indirect": return 10
        case "low": return 14
        default: return 10
        }
    }
    
    private func estimateHumidityPreference() -> HumidityPreference {
        let notes = careNotes.lowercased()
        if notes.contains("high humidity") || notes.contains("mist") || notes.contains("humid") {
            return .high
        }
        if notes.contains("low humidity") || notes.contains("dry") {
            return .low
        }
        return .medium
    }
    
    private func extractRotationFrequency() -> String? {
        let notes = careNotes.lowercased()
        if notes.contains("rotate") {
            // Try to extract rotation frequency
            if notes.contains("weekly") { return "Rotate weekly" }
            if notes.contains("every week") { return "Rotate weekly" }
            if notes.contains("every 2 weeks") { return "Rotate every 2 weeks" }
            if notes.contains("every two weeks") { return "Rotate every 2 weeks" }
            if notes.contains("every 3 weeks") { return "Rotate every 3 weeks" }
            if notes.contains("monthly") { return "Rotate monthly" }
            if notes.contains("every month") { return "Rotate monthly" }
            return "Rotate periodically"
        }
        return nil
    }
}