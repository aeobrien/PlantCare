import Foundation

class OpenAIService {
    static let shared = OpenAIService()
    private init() {}
    
    private let baseURL = "https://api.openai.com/v1/chat/completions"
    
    func generatePlantRecommendation(plantName: String, rooms: [Room], apiKey: String) async throws -> AIPlantResponse {
        // Create the room information JSON
        let roomsInfo = rooms.map { room in
            [
                "name": room.name,
                "windows": room.windows.map { window in
                    ["direction": window.direction.rawValue]
                }
            ]
        }
        
        let roomsJSON = try JSONSerialization.data(withJSONObject: roomsInfo, options: .prettyPrinted)
        let roomsString = String(data: roomsJSON, encoding: .utf8) ?? "[]"
        
        // Create the prompt
        let systemPrompt = """
        You are a plant care expert assistant. Your role is to provide detailed care recommendations for plants based on their species and the user's home layout.
        
        You must respond with ONLY a valid JSON object. Do not include any other text, markdown formatting, or explanations. Just return the raw JSON matching this exact structure:
        {
            "name": "Plant Name",
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
            "recommendedRooms": ["First choice room name", "Second choice room name"]
        }
        
        Base your room recommendations on:
        1. The plant's light requirements vs available window directions
        2. The plant's humidity needs
        3. Temperature preferences (south-facing rooms tend to be warmer)
        
        Provide at least 2 room recommendations ordered by suitability.
        Remember: Return ONLY the JSON object, no other text.
        """
        
        let userPrompt = """
        I have a \(plantName) and need care recommendations.
        
        My home has the following rooms:
        \(roomsString)
        
        Please provide complete care instructions and recommend the best rooms for this plant based on its needs and my available rooms.
        """
        
        // Create the request
        let messages = [
            OpenAIMessage(role: "system", content: MessageContent.text(systemPrompt)),
            OpenAIMessage(role: "user", content: MessageContent.text(userPrompt))
        ]
        
        let request = OpenAIRequest(
            model: "gpt-3.5-turbo",
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
    
    func askPlantQuestion(question: String, plant: Plant, rooms: [Room], photoData: Data?, apiKey: String) async throws -> AIPlantQuestionResponse {
        // Create the plant information JSON
        let plantInfo: [String: Any] = [
            "name": plant.name,
            "currentRoom": rooms.first(where: { $0.id == plant.assignedRoomID })?.name ?? "Not assigned",
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
        
        // Create rooms info JSON
        let roomsInfo = rooms.map { room in
            [
                "name": room.name,
                "windows": room.windows.map { window in
                    ["direction": window.direction.rawValue]
                }
            ]
        }
        
        let roomsJSON = try JSONSerialization.data(withJSONObject: roomsInfo, options: .prettyPrinted)
        let roomsString = String(data: roomsJSON, encoding: .utf8) ?? "[]"
        
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
        6. Base room recommendations on the plant's needs and available rooms/windows
        
        Remember: Return ONLY the JSON object, no other text.
        """
        
        let userPrompt = """
        Current plant information:
        \(plantString)
        
        Available rooms in the home:
        \(roomsString)
        
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
            model: photoData != nil ? "gpt-4o" : "gpt-3.5-turbo",
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