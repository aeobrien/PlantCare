import Foundation

struct AIPlantResponse: Codable {
    let name: String
    let lightType: LightType
    let preferredLightDirection: Direction
    let humidityPreference: HumidityPreference?
    let wateringInstructions: String
    let wateringFrequencyDays: Int
    let mistingInstructions: String?
    let mistingFrequencyDays: Int?
    let dustingInstructions: String?
    let dustingFrequencyDays: Int?
    let rotationInstructions: String?
    let rotationFrequencyDays: Int?
    let generalNotes: String
    let recommendedRooms: [String]
}

struct OpenAIRequest: Codable {
    let model: String
    let messages: [OpenAIMessage]
    let temperature: Double
    let response_format: ResponseFormat?
    
    struct ResponseFormat: Codable {
        let type: String
    }
}

struct OpenAIMessage: Codable {
    let role: String
    let content: String
}

struct OpenAIResponse: Codable {
    let choices: [Choice]
    
    struct Choice: Codable {
        let message: Message
        
        struct Message: Codable {
            let content: String
        }
    }
}

struct AIPlantQuestionResponse: Codable {
    let answer: String
    let suggestedChanges: PlantChangeSuggestion?
}

struct PlantChangeSuggestion: Codable {
    let name: String?
    let assignedRoomID: String?
    let assignedWindowID: String?
    let lightType: LightType?
    let preferredLightDirection: Direction?
    let humidityPreference: HumidityPreference?
    let generalNotes: String?
    let careSteps: [CareSuggestion]?
}

struct CareSuggestion: Codable {
    let type: CareStepType
    let customName: String?
    let instructions: String?
    let frequencyDays: Int?
}