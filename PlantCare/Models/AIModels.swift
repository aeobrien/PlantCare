import Foundation

struct AIPlantResponse: Codable {
    let name: String
    let latinName: String?
    let visualDescription: String?
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
    let recommendedRooms: [String]?  // Legacy support
    let recommendedSpaces: [String]?
    let recommendedSpaceTypes: [String]?
    
    // Computed property for backward compatibility
    var spaces: [String] {
        recommendedSpaces ?? recommendedRooms ?? []
    }
    
    var spaceTypes: [String] {
        recommendedSpaceTypes ?? Array(repeating: "indoor", count: spaces.count)
    }
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
    let content: MessageContent
}

enum MessageContent: Codable {
    case text(String)
    case array([ContentItem])
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) {
            self = .text(text)
        } else if let array = try? container.decode([ContentItem].self) {
            self = .array(array)
        } else {
            throw DecodingError.typeMismatch(MessageContent.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Expected String or Array"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .text(let text):
            try container.encode(text)
        case .array(let array):
            try container.encode(array)
        }
    }
}

struct ContentItem: Codable {
    let type: String
    let text: String?
    let image_url: ImageURL?
    
    struct ImageURL: Codable {
        let url: String
    }
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