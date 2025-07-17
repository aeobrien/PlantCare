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
            "visualDescription": "A simple one-sentence description of what the plant looks like to help identify it (e.g., 'Large leafy plant with holes in the leaves' or 'Tall snake-like leaves with yellow edges')",
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
    
    func askPlantQuestion(question: String, plant: Plant, rooms: [Room], zones: [Zone], photoData: Data?, previousMessages: [ConversationMessage] = [], apiKey: String) async throws -> AIPlantQuestionResponse {
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
        1. Keep your answer brief and to the point (4-5 sentences max)
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
        var messages: [OpenAIMessage] = [
            OpenAIMessage(role: "system", content: MessageContent.text(systemPrompt))
        ]
        
        // Add conversation history if available
        if !previousMessages.isEmpty {
            // Add initial context message
            messages.append(OpenAIMessage(role: "user", content: MessageContent.text(userPrompt)))
            
            // Add previous conversation messages
            for message in previousMessages {
                if message.role == "user" {
                    messages.append(OpenAIMessage(role: "user", content: MessageContent.text(message.content)))
                } else {
                    messages.append(OpenAIMessage(role: "assistant", content: MessageContent.text(message.content)))
                }
            }
            
            // Add current question
            if let photoData = photoData {
                let base64Image = photoData.base64EncodedString()
                let imageUrl = "data:image/jpeg;base64,\(base64Image)"
                
                let userContent = MessageContent.array([
                    ContentItem(type: "text", text: question, image_url: nil),
                    ContentItem(type: "image_url", text: nil, image_url: ContentItem.ImageURL(url: imageUrl))
                ])
                messages.append(OpenAIMessage(role: "user", content: userContent))
            } else {
                messages.append(OpenAIMessage(role: "user", content: MessageContent.text(question)))
            }
        } else {
            // First message - include full context
            if let photoData = photoData {
                // Convert image data to base64
                let base64Image = photoData.base64EncodedString()
                let imageUrl = "data:image/jpeg;base64,\(base64Image)"
                
                let userContent = MessageContent.array([
                    ContentItem(type: "text", text: userPrompt, image_url: nil),
                    ContentItem(type: "image_url", text: nil, image_url: ContentItem.ImageURL(url: imageUrl))
                ])
                
                messages.append(OpenAIMessage(role: "user", content: userContent))
            } else {
                messages.append(OpenAIMessage(role: "user", content: MessageContent.text(userPrompt)))
            }
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
    
    func performPlantCareVibeCheck(plants: [Plant], rooms: [Room], zones: [Zone], apiKey: String) async throws -> PlantCareVibeCheckResponse {
        // Create plant information JSON
        var plantsInfo: [[String: Any]] = []
        
        for plant in plants {
            var plantInfo: [String: Any] = [
                "id": plant.id.uuidString,
                "name": plant.name,
                "latinName": plant.latinName ?? "",
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
                        "isEnabled": careStep.isEnabled
                    ] as [String : Any]
                }
            ]
            
            // Add location info
            if let roomID = plant.assignedRoomID, let room = rooms.first(where: { $0.id == roomID }) {
                plantInfo["location"] = room.name
                plantInfo["locationType"] = "indoor"
                if let windowID = plant.assignedWindowID, let window = room.windows.first(where: { $0.id == windowID }) {
                    plantInfo["windowDirection"] = window.direction.rawValue
                }
            } else if let zoneID = plant.assignedZoneID, let zone = zones.first(where: { $0.id == zoneID }) {
                plantInfo["location"] = zone.name
                plantInfo["locationType"] = "outdoor"
                plantInfo["zoneAspect"] = zone.aspect.rawValue
                plantInfo["zoneSunPeriod"] = zone.sunPeriod.rawValue
            }
            
            plantsInfo.append(plantInfo)
        }
        
        let plantsJSON = try JSONSerialization.data(withJSONObject: plantsInfo, options: .prettyPrinted)
        let plantsString = String(data: plantsJSON, encoding: .utf8) ?? "[]"
        
        let systemPrompt = """
        You are a plant care expert reviewing a user's plant collection and care settings. Your role is to:
        1. Review all plants and their care instructions
        2. Identify any care settings that seem incorrect or could be optimized
        3. Look for plants that might have unnecessary care steps (e.g., dusting for plants that don't need it, misting for succulents)
        4. Check if watering intervals and instructions are appropriate for each plant type
        5. Verify light requirements match their placement
        
        You must respond with ONLY a valid JSON object. Do not include any other text, markdown formatting, or explanations. Just return the raw JSON matching this exact structure:
        {
            "overall": "Brief 1-2 sentence summary of the overall care setup quality",
            "suggestions": [
                {
                    "plantId": "UUID string of the plant",
                    "plantName": "Name of the plant",
                    "field": "wateringFrequencyDays" | "wateringInstructions" | "mistingFrequencyDays" | "mistingInstructions" | "dustingFrequencyDays" | "dustingInstructions" | "rotationFrequencyDays" | "rotationInstructions" | "removeWatering" | "removeMisting" | "removeDusting" | "removeRotation" | "lightType" | "humidityPreference" | "location",
                    "currentValue": "Current value as string",
                    "suggestedValue": "Suggested value as string",
                    "reason": "Brief explanation why this change is recommended"
                }
            ]
        }
        
        IMPORTANT RULES:
        1. Only suggest changes that would genuinely improve plant care
        2. Be specific about which care steps to modify or remove
        3. For removal suggestions, use "removeWatering", "removeMisting", etc. as the field
        4. For frequency changes, the field should be like "wateringFrequencyDays"
        5. For instruction changes, the field should be like "wateringInstructions"
        6. Keep reasons brief and clear
        7. If everything looks good, return an empty suggestions array
        
        Remember: Return ONLY the JSON object, no other text.
        """
        
        let userPrompt = """
        Please review my plant collection and suggest any improvements to the care settings:
        
        \(plantsString)
        """
        
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
        
        // Clean and parse the response
        var cleanedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanedContent.hasPrefix("```json") {
            cleanedContent = cleanedContent.replacingOccurrences(of: "```json", with: "")
        }
        if cleanedContent.hasPrefix("```") {
            cleanedContent = cleanedContent.replacingOccurrences(of: "```", with: "")
        }
        cleanedContent = cleanedContent.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if let startIndex = cleanedContent.firstIndex(of: "{"),
           let endIndex = cleanedContent.lastIndex(of: "}") {
            let jsonRange = startIndex...endIndex
            cleanedContent = String(cleanedContent[jsonRange])
        }
        
        guard let contentData = cleanedContent.data(using: .utf8) else {
            throw APIError.invalidResponse
        }
        
        let vibeCheckResponse = try JSONDecoder().decode(PlantCareVibeCheckResponse.self, from: contentData)
        return vibeCheckResponse
    }
    
    func performPlantHealthCheck(plantId: String, plantName: String, recentPhotos: [Data], apiKey: String) async throws -> PlantHealthCheckResponse {
        let systemPrompt = """
        You are a plant health expert analyzing photos of a plant. Based on the images provided:
        1. Assess the overall health of the plant
        2. Look for signs of stress, disease, pests, or nutrient deficiencies
        3. Note any positive aspects of the plant's condition
        4. Provide actionable advice if any issues are detected
        
        You must respond with ONLY a valid JSON object:
        {
            "plantId": "The plant ID provided",
            "feedback": "1-2 sentences of feedback about the plant's health and any advice"
        }
        
        Keep your feedback concise, friendly, and actionable. Focus on the most important observations.
        Remember: Return ONLY the JSON object, no other text.
        """
        
        // Convert photos to base64
        let photoContents = recentPhotos.prefix(3).map { photoData in
            ContentItem(
                type: "image_url",
                text: nil,
                image_url: ContentItem.ImageURL(url: "data:image/jpeg;base64,\(photoData.base64EncodedString())")
            )
        }
        
        var userContent = [ContentItem(type: "text", text: "Please analyze the health of my \(plantName) based on these recent photos:", image_url: nil)]
        userContent.append(contentsOf: photoContents)
        
        let messages = [
            OpenAIMessage(role: "system", content: MessageContent.text(systemPrompt)),
            OpenAIMessage(role: "user", content: MessageContent.array(userContent))
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
        
        // Clean and parse the response
        var cleanedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if let startIndex = cleanedContent.firstIndex(of: "{"),
           let endIndex = cleanedContent.lastIndex(of: "}") {
            let jsonRange = startIndex...endIndex
            cleanedContent = String(cleanedContent[jsonRange])
        }
        
        guard let contentData = cleanedContent.data(using: .utf8) else {
            throw APIError.invalidResponse
        }
        
        let healthCheckResponse = try JSONDecoder().decode(PlantHealthCheckResponse.self, from: contentData)
        return healthCheckResponse
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
