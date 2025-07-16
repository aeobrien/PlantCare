import Foundation

class OpenAIService {
    static let shared = OpenAIService()
    private init() {}
    
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    
    func generatePlantRecommendation(plantName: String, rooms: [Room], zones: [Zone], preference: SpacePlacementPreference, apiKey: String) async throws -> AIPlantResponse {
        // Create the room and zone information JSON
        let roomsInfo = rooms.map { room in
            [
                "name": room.name,
                "type": "indoor",
                "windows": room.windows.map { window in
                    ["direction": window.direction.rawValue]
                }
            ]
        }
        
        let zonesInfo = zones.map { zone in
            [
                "name": zone.name,
                "type": "outdoor",
                "aspect": zone.aspect.rawValue,
                "sunPeriod": zone.sunPeriod.rawValue,
                "wind": zone.wind.rawValue,
                "sunHours": zone.sunHours?.rawValue ?? zone.inferredSunHours.rawValue
            ]
        }
        
        let spacesInfo = roomsInfo + zonesInfo
        let spacesJSON = try JSONSerialization.data(withJSONObject: spacesInfo, options: .prettyPrinted)
        let spacesString = String(data: spacesJSON, encoding: .utf8) ?? "[]"
        
        // Create the prompt
        let systemPrompt = """
        You are a plant care expert assistant. Your role is to provide detailed care recommendations for plants based on their species and the user's home layout including both indoor and outdoor spaces.
        
        You must respond with ONLY a valid JSON object. Do not include any other text, markdown formatting, or explanations. Just return the raw JSON matching this exact structure:
        {
            "name": "Plant Name",
            "latinName": "Scientific name in Latin (optional)",
            "lightType": "Direct" | "Indirect" | "Low",
            "preferredLightDirection": "North" | "Northeast" | "East" | "Southeast" | "South" | "Southwest" | "West" | "Northwest",
            "humidityPreference": "Low" | "Medium" | "High",
            "wateringInstructions": "Detailed watering instructions",
            "wateringFrequencyDays": number,
            "mistingInstructions": "Misting instructions (optional)",
            "mistingFrequencyDays": number (optional),
            "dustingInstructions": "Dusting instructions (optional)",
            "dustingFrequencyDays": number (optional),
            "rotationInstructions": "Rotation instructions (optional)",
            "rotationFrequencyDays": number (optional),
            "generalNotes": "General care notes and tips",
            "recommendedSpaces": ["First choice space name", "Second choice space name"],
            "recommendedSpaceTypes": ["indoor" | "outdoor", "indoor" | "outdoor"]
        }
        
        Base your space recommendations on:
        
        For indoor spaces:
        1. The plant's light requirements vs available window directions
        2. The plant's humidity needs
        3. Temperature preferences (south-facing rooms tend to be warmer)
        
        For outdoor zones:
        1. Plant hardiness and outdoor suitability
        2. Sun exposure (aspect, sun period, sun hours)
        3. Wind tolerance vs zone wind exposure
        4. Whether the plant can thrive outdoors in typical conditions
        
        Consider the user's placement preference but also factor in plant suitability.
        If a plant is not suitable for outdoor placement, recommend only indoor spaces even if outdoor was preferred.
        
        Provide at least 2 space recommendations ordered by suitability.
        Remember: Return ONLY the JSON object, no other text.
        """
        
        let userPrompt = """
        I have a \(plantName) and need care recommendations.
        
        My placement preference is: \(preference.rawValue)
        
        My home has the following spaces:
        \(spacesString)
        
        Please provide complete care instructions and recommend the best spaces for this plant based on its needs, my preference, and my available spaces.
        """
        
        // Create the request
        let messages = [
            OpenAIMessage(role: "system", content: MessageContent.text(systemPrompt)),
            OpenAIMessage(role: "user", content: MessageContent.text(userPrompt))
        ]
        
        let request = OpenAIRequest(
            model: "gpt-4o-mini",
            messages: messages,
            temperature: 0.7,
            response_format: nil
        )
        
        // Make the API call
        var urlRequest = URLRequest(url: URL(string: baseURL)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            if let errorData = try? JSONDecoder().decode(OpenAIError.self, from: data) {
                throw APIError.openAIError(errorData.error.message)
            }
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        
        guard let content = openAIResponse.choices.first?.message.content else {
            throw APIError.invalidResponse
        }
        
        // Clean the content to extract JSON (in case there's any extra text)
        var cleanedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove markdown code blocks if present
        if cleanedContent.hasPrefix("```json") {
            cleanedContent = cleanedContent.replacingOccurrences(of: "```json", with: "")
        }
        if cleanedContent.hasPrefix("```") {
            cleanedContent = cleanedContent.replacingOccurrences(of: "```", with: "")
        }
        cleanedContent = cleanedContent.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Find the JSON object (starts with { and ends with })
        if let startIndex = cleanedContent.firstIndex(of: "{"),
           let endIndex = cleanedContent.lastIndex(of: "}") {
            let jsonRange = startIndex...endIndex
            cleanedContent = String(cleanedContent[jsonRange])
        }
        
        guard let contentData = cleanedContent.data(using: .utf8) else {
            throw APIError.invalidResponse
        }
        
        // Parse the AI response
        let plantResponse = try JSONDecoder().decode(AIPlantResponse.self, from: contentData)
        
        return plantResponse
    }
    
    func askPlantQuestion(question: String, plant: Plant, rooms: [Room], zones: [Zone], photoData: Data?, apiKey: String) async throws -> AIPlantQuestionResponse {
        // Create the plant information JSON
        let currentLocation: String
        let currentLocationType: String
        
        if let roomID = plant.assignedRoomID, let room = rooms.first(where: { $0.id == roomID }) {
            currentLocation = room.name
            currentLocationType = "indoor"
        } else if let zoneID = plant.assignedZoneID, let zone = zones.first(where: { $0.id == zoneID }) {
            currentLocation = zone.name
            currentLocationType = "outdoor"
        } else {
            currentLocation = "Not assigned"
            currentLocationType = "none"
        }
        
        let plantInfo: [String: Any] = [
            "name": plant.name,
            "currentLocation": currentLocation,
            "currentLocationType": currentLocationType,
            "currentWindow": plant.assignedWindowID != nil ? 
                rooms.flatMap { $0.windows }.first(where: { $0.id == plant.assignedWindowID })?.direction.rawValue ?? "Unknown" : 
                "Not assigned to window",
            "lightType": plant.lightType.rawValue,
            "preferredLightDirection": plant.preferredLightDirection.rawValue,
            "humidityPreference": plant.humidityPreference?.rawValue ?? "Not specified",
            "generalNotes": plant.generalNotes,
            "careSteps": plant.careSteps.map { careStep in
                [
                    "type": careStep.type.rawValue,
                    "displayName": careStep.displayName,
                    "instructions": careStep.instructions,
                    "frequencyDays": careStep.frequencyDays,
                    "isOverdue": careStep.isOverdue,
                    "daysUntilDue": careStep.daysUntilDue ?? 0,
                    "lastCompleted": careStep.lastCompletedDate?.formatted() ?? "Never"
                ] as [String : Any]
            }
        ]
        
        let plantJSON = try JSONSerialization.data(withJSONObject: plantInfo, options: .prettyPrinted)
        let plantString = String(data: plantJSON, encoding: .utf8) ?? "{}"
        
        // Create spaces info JSON
        let roomsInfo = rooms.map { room in
            [
                "name": room.name,
                "type": "indoor",
                "windows": room.windows.map { window in
                    ["direction": window.direction.rawValue]
                }
            ]
        }
        
        let zonesInfo = zones.map { zone in
            [
                "name": zone.name,
                "type": "outdoor",
                "aspect": zone.aspect.rawValue,
                "sunPeriod": zone.sunPeriod.rawValue,
                "wind": zone.wind.rawValue,
                "sunHours": zone.sunHours?.rawValue ?? zone.inferredSunHours.rawValue
            ]
        }
        
        let spacesInfo = roomsInfo + zonesInfo
        let spacesJSON = try JSONSerialization.data(withJSONObject: spacesInfo, options: .prettyPrinted)
        let spacesString = String(data: spacesJSON, encoding: .utf8) ?? "[]"
        
        // Create the prompt
        let systemPrompt = """
        You are a plant care expert assistant. You are being asked a question about a specific plant and its care. If an image is provided, analyze it thoroughly to provide more accurate advice.
        
        You must respond with ONLY a valid JSON object. Do not include any other text, markdown formatting, or explanations. Just return the raw JSON matching this exact structure:
        {
            "answer": "Your brief, helpful answer to the user's question",
            "suggestedChanges": {
                "name": "New name (only if changing)",
                "assignedRoomID": "Room name (only if suggesting a different room)",
                "lightType": "Direct" | "Indirect" | "Low" (only if changing),
                "preferredLightDirection": "North" | "Northeast" | "East" | "Southeast" | "South" | "Southwest" | "West" | "Northwest" (only if changing),
                "humidityPreference": "Low" | "Medium" | "High" (only if changing),
                "generalNotes": "Updated notes (only if changing)",
                "careSteps": [
                    {
                        "type": "Watering" | "Misting" | "Dusting" | "Rotation" | "Custom",
                        "customName": "Custom name if type is Custom",
                        "instructions": "Updated instructions",
                        "frequencyDays": number
                    }
                ]
            }
        }
        
        IMPORTANT RULES:
        1. Keep your answer brief and to the point (2-3 sentences max)
        2. Only include fields in suggestedChanges if you are actually suggesting a change
        3. If no changes are suggested, set suggestedChanges to null
        4. For assignedRoomID, use the room NAME (not an ID) if suggesting a room change
        5. Only suggest changes that directly relate to the user's question
        6. Base space recommendations on the plant's needs and available spaces (both indoor rooms and outdoor zones)
        7. For outdoor zones, consider plant hardiness, sun tolerance, and wind exposure
        8. For assignedRoomID, use the space NAME regardless of whether it's indoor or outdoor
        
        Remember: Return ONLY the JSON object, no other text.
        """
        
        let userPrompt = """
        Current plant information:
        \(plantString)
        
        Available spaces in the home (both indoor and outdoor):
        \(spacesString)
        
        User's question: \(question)
        \(photoData != nil ? "\n\nI've included a photo of the plant for your analysis." : "")
        """
        
        // Create the request with image support if photo is provided
        let messages: [OpenAIMessage]
        
        if let photoData = photoData {
            // Convert image data to base64
            let base64Image = photoData.base64EncodedString()
            let imageUrl = "data:image/jpeg;base64,\(base64Image)"
            
            let userContent = MessageContent.array([
                ContentItem(type: "text", text: userPrompt, image_url: nil),
                ContentItem(type: "image_url", text: nil, image_url: ContentItem.ImageURL(url: imageUrl))
            ])
            
            messages = [
                OpenAIMessage(role: "system", content: MessageContent.text(systemPrompt)),
                OpenAIMessage(role: "user", content: userContent)
            ]
        } else {
            messages = [
                OpenAIMessage(role: "system", content: MessageContent.text(systemPrompt)),
                OpenAIMessage(role: "user", content: MessageContent.text(userPrompt))
            ]
        }
        
        let request = OpenAIRequest(
            model: photoData != nil ? "gpt-4o-mini" : "gpt-4o-mini",
            messages: messages,
            temperature: 0.7,
            response_format: nil
        )
        
        // Make the API call
        var urlRequest = URLRequest(url: URL(string: baseURL)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            if let errorData = try? JSONDecoder().decode(OpenAIError.self, from: data) {
                throw APIError.openAIError(errorData.error.message)
            }
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        
        guard let content = openAIResponse.choices.first?.message.content else {
            throw APIError.invalidResponse
        }
        
        // Clean the content to extract JSON
        var cleanedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Remove markdown code blocks if present
        if cleanedContent.hasPrefix("```json") {
            cleanedContent = cleanedContent.replacingOccurrences(of: "```json", with: "")
        }
        if cleanedContent.hasPrefix("```") {
            cleanedContent = cleanedContent.replacingOccurrences(of: "```", with: "")
        }
        cleanedContent = cleanedContent.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Find the JSON object
        if let startIndex = cleanedContent.firstIndex(of: "{"),
           let endIndex = cleanedContent.lastIndex(of: "}") {
            let jsonRange = startIndex...endIndex
            cleanedContent = String(cleanedContent[jsonRange])
        }
        
        guard let contentData = cleanedContent.data(using: .utf8) else {
            throw APIError.invalidResponse
        }
        
        // Parse the AI response
        let questionResponse = try JSONDecoder().decode(AIPlantQuestionResponse.self, from: contentData)
        
        return questionResponse
    }
    
    func identifyPlant(from imageData: Data, apiKey: String) async throws -> String {
        let base64Image = imageData.base64EncodedString()
        let imageUrl = "data:image/jpeg;base64,\(base64Image)"
        
        let systemPrompt = """
        You are a plant identification expert. Analyze the provided image and identify the plant species.
        Return ONLY the common name and Latin name of the plant in this exact format:
        Common Name (Latin name)
        
        For example:
        Monstera Deliciosa (Monstera deliciosa)
        Snake Plant (Sansevieria trifasciata)
        
        If you cannot identify the plant with certainty, return "Unknown Plant".
        Do not include any other text, explanations, or formatting.
        """
        
        let userContent = MessageContent.array([
            ContentItem(type: "text", text: "Please identify this plant:", image_url: nil),
            ContentItem(type: "image_url", text: nil, image_url: ContentItem.ImageURL(url: imageUrl))
        ])
        
        let messages = [
            OpenAIMessage(role: "system", content: MessageContent.text(systemPrompt)),
            OpenAIMessage(role: "user", content: userContent)
        ]
        
        let request = OpenAIRequest(
            model: "gpt-4o-mini",
            messages: messages,
            temperature: 0.3,
            response_format: nil
        )
        
        // Make the API call
        var urlRequest = URLRequest(url: URL(string: baseURL)!)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        urlRequest.httpBody = try JSONEncoder().encode(request)
        
        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        
        if httpResponse.statusCode != 200 {
            if let errorData = try? JSONDecoder().decode(OpenAIError.self, from: data) {
                throw APIError.openAIError(errorData.error.message)
            }
            throw APIError.httpError(httpResponse.statusCode)
        }
        
        let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)
        
        guard let content = openAIResponse.choices.first?.message.content else {
            throw APIError.openAIError("No response content")
        }
        
        return content.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
    }
}

enum APIError: LocalizedError {
    case invalidResponse
    case httpError(Int)
    case openAIError(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .openAIError(let message):
            return "OpenAI API error: \(message)"
        }
    }
}

struct OpenAIError: Codable {
    let error: ErrorDetail
    
    struct ErrorDetail: Codable {
        let message: String
        let type: String?
        let param: String?
        let code: String?
    }
}
