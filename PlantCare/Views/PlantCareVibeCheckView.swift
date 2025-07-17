import SwiftUI

struct PlantCareVibeCheckView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss
    @State private var isLoading = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var vibeCheckResponse: PlantCareVibeCheckResponse?
    @State private var acceptedChanges: Set<String> = []
    @State private var rejectedChanges: Set<String> = []
    
    var pendingSuggestions: [PlantCareRevision] {
        vibeCheckResponse?.suggestions.filter { suggestion in
            !acceptedChanges.contains(suggestion.plantId + suggestion.field) &&
            !rejectedChanges.contains(suggestion.plantId + suggestion.field)
        } ?? []
    }
    
    var acceptedSuggestions: [PlantCareRevision] {
        vibeCheckResponse?.suggestions.filter { suggestion in
            acceptedChanges.contains(suggestion.plantId + suggestion.field)
        } ?? []
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading {
                    VibeCheckLoadingView()
                } else if let response = vibeCheckResponse {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // Overall assessment
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Image(systemName: "sparkles")
                                        .foregroundColor(.blue)
                                    Text("AI Assessment")
                                        .font(.headline)
                                }
                                
                                Text(response.overall)
                                    .font(.body)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                            }
                            .padding(.horizontal)
                            
                            if !response.suggestions.isEmpty {
                                VStack(alignment: .leading, spacing: 16) {
                                    Text("Suggested Changes")
                                        .font(.headline)
                                        .padding(.horizontal)
                                    
                                    if !pendingSuggestions.isEmpty {
                                        Text("Review each suggestion below:")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                            .padding(.horizontal)
                                        
                                        ForEach(pendingSuggestions, id: \.plantId) { suggestion in
                                            SuggestionCard(
                                                suggestion: suggestion,
                                                onAccept: {
                                                    acceptedChanges.insert(suggestion.plantId + suggestion.field)
                                                },
                                                onReject: {
                                                    rejectedChanges.insert(suggestion.plantId + suggestion.field)
                                                }
                                            )
                                            .padding(.horizontal)
                                        }
                                    }
                                    
                                    if !acceptedSuggestions.isEmpty {
                                        VStack(alignment: .leading, spacing: 8) {
                                            Text("Accepted Changes (\(acceptedSuggestions.count))")
                                                .font(.subheadline)
                                                .foregroundColor(.secondary)
                                                .padding(.horizontal)
                                            
                                            ForEach(acceptedSuggestions, id: \.plantId) { suggestion in
                                                HStack {
                                                    Image(systemName: "checkmark.circle.fill")
                                                        .foregroundColor(.green)
                                                    Text("\(suggestion.plantName): \(suggestion.field)")
                                                        .font(.caption)
                                                        .foregroundColor(.secondary)
                                                }
                                                .padding(.horizontal)
                                            }
                                        }
                                    }
                                }
                            } else {
                                VStack(spacing: 12) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 50))
                                        .foregroundColor(.green)
                                    
                                    Text("Everything looks great!")
                                        .font(.title3)
                                        .fontWeight(.medium)
                                    
                                    Text("No changes recommended at this time.")
                                        .font(.body)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                            }
                        }
                        .padding(.vertical)
                    }
                    
                    if !acceptedSuggestions.isEmpty {
                        VStack {
                            Divider()
                            
                            Button(action: applyChanges) {
                                HStack {
                                    Image(systemName: "checkmark.circle")
                                    Text("Apply \(acceptedSuggestions.count) Changes")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                            .padding()
                        }
                        .background(Color(.systemBackground))
                    }
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("Plant Care Vibe Check")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Let AI review your plant care settings and suggest improvements")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button(action: performVibeCheck) {
                            HStack {
                                Image(systemName: "sparkles")
                                Text("Start Vibe Check")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .padding(.horizontal)
                    }
                    .padding()
                }
            }
            .navigationTitle("Plant Care Vibe Check")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                if vibeCheckResponse != nil && pendingSuggestions.isEmpty && acceptedSuggestions.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    func performVibeCheck() {
        guard !dataStore.settings.openAIAPIKey.isEmpty else {
            errorMessage = "Please configure your OpenAI API key in Settings"
            showingError = true
            return
        }
        
        isLoading = true
        
        Task {
            do {
                let response = try await OpenAIService.shared.performPlantCareVibeCheck(
                    plants: dataStore.plants,
                    rooms: dataStore.rooms,
                    zones: dataStore.zones,
                    apiKey: dataStore.settings.openAIAPIKey
                )
                
                await MainActor.run {
                    self.vibeCheckResponse = response
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.showingError = true
                    self.isLoading = false
                }
            }
        }
    }
    
    func applyChanges() {
        for suggestion in acceptedSuggestions {
            if let plantIndex = dataStore.plants.firstIndex(where: { $0.id.uuidString == suggestion.plantId }) {
                var plant = dataStore.plants[plantIndex]
                
                switch suggestion.field {
                case "wateringFrequencyDays":
                    if let frequency = Int(suggestion.suggestedValue),
                       let wateringStep = plant.careSteps.first(where: { $0.type == .watering }) {
                        var updatedStep = wateringStep
                        updatedStep.frequencyDays = frequency
                        plant.updateCareStep(updatedStep)
                    }
                    
                case "wateringInstructions":
                    if let wateringStep = plant.careSteps.first(where: { $0.type == .watering }) {
                        var updatedStep = wateringStep
                        updatedStep.instructions = suggestion.suggestedValue
                        plant.updateCareStep(updatedStep)
                    }
                    
                case "mistingFrequencyDays":
                    if let frequency = Int(suggestion.suggestedValue),
                       let mistingStep = plant.careSteps.first(where: { $0.type == .misting }) {
                        var updatedStep = mistingStep
                        updatedStep.frequencyDays = frequency
                        plant.updateCareStep(updatedStep)
                    }
                    
                case "mistingInstructions":
                    if let mistingStep = plant.careSteps.first(where: { $0.type == .misting }) {
                        var updatedStep = mistingStep
                        updatedStep.instructions = suggestion.suggestedValue
                        plant.updateCareStep(updatedStep)
                    }
                    
                case "dustingFrequencyDays":
                    if let frequency = Int(suggestion.suggestedValue),
                       let dustingStep = plant.careSteps.first(where: { $0.type == .dusting }) {
                        var updatedStep = dustingStep
                        updatedStep.frequencyDays = frequency
                        plant.updateCareStep(updatedStep)
                    }
                    
                case "dustingInstructions":
                    if let dustingStep = plant.careSteps.first(where: { $0.type == .dusting }) {
                        var updatedStep = dustingStep
                        updatedStep.instructions = suggestion.suggestedValue
                        plant.updateCareStep(updatedStep)
                    }
                    
                case "rotationFrequencyDays":
                    if let frequency = Int(suggestion.suggestedValue),
                       let rotationStep = plant.careSteps.first(where: { $0.type == .rotation }) {
                        var updatedStep = rotationStep
                        updatedStep.frequencyDays = frequency
                        plant.updateCareStep(updatedStep)
                    }
                    
                case "rotationInstructions":
                    if let rotationStep = plant.careSteps.first(where: { $0.type == .rotation }) {
                        var updatedStep = rotationStep
                        updatedStep.instructions = suggestion.suggestedValue
                        plant.updateCareStep(updatedStep)
                    }
                    
                case "removeMisting":
                    plant.careSteps.removeAll { $0.type == .misting }
                    
                case "removeDusting":
                    plant.careSteps.removeAll { $0.type == .dusting }
                    
                case "removeRotation":
                    plant.careSteps.removeAll { $0.type == .rotation }
                    
                case "lightType":
                    if let lightType = LightType(rawValue: suggestion.suggestedValue) {
                        plant.lightType = lightType
                    }
                    
                case "humidityPreference":
                    if let humidity = HumidityPreference(rawValue: suggestion.suggestedValue) {
                        plant.humidityPreference = humidity
                    }
                    
                default:
                    break
                }
                
                dataStore.updatePlant(plant)
            }
        }
        
        dismiss()
    }
}

struct SuggestionCard: View {
    let suggestion: PlantCareRevision
    let onAccept: () -> Void
    let onReject: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.plantName)
                        .font(.headline)
                    
                    Text(formatFieldName(suggestion.field))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 16) {
                    Button(action: onReject) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.red)
                            .font(.title2)
                    }
                    
                    Button(action: onAccept) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.title2)
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Text("Current:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .frame(width: 60, alignment: .leading)
                    
                    Text(suggestion.currentValue)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                HStack(alignment: .top) {
                    Text("Suggested:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .frame(width: 60, alignment: .leading)
                    
                    Text(suggestion.suggestedValue)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                
                HStack(alignment: .top) {
                    Text("Reason:")
                        .font(.caption)
                        .fontWeight(.medium)
                        .frame(width: 60, alignment: .leading)
                    
                    Text(suggestion.reason)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    func formatFieldName(_ field: String) -> String {
        switch field {
        case "wateringFrequencyDays": return "Watering Frequency"
        case "wateringInstructions": return "Watering Instructions"
        case "mistingFrequencyDays": return "Misting Frequency"
        case "mistingInstructions": return "Misting Instructions"
        case "dustingFrequencyDays": return "Dusting Frequency"
        case "dustingInstructions": return "Dusting Instructions"
        case "rotationFrequencyDays": return "Rotation Frequency"
        case "rotationInstructions": return "Rotation Instructions"
        case "removeMisting": return "Remove Misting"
        case "removeDusting": return "Remove Dusting"
        case "removeRotation": return "Remove Rotation"
        case "lightType": return "Light Type"
        case "humidityPreference": return "Humidity Preference"
        case "location": return "Location"
        default: return field
        }
    }
}

struct VibeCheckLoadingView: View {
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("Analyzing your plants...")
                .font(.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}