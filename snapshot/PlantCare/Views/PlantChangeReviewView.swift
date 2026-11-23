import SwiftUI
import Foundation

struct PlantChangeReviewView: View {
    let plant: Plant
    let suggestedChanges: PlantChangeSuggestion
    let onApprove: (Plant) -> Void
    
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedChanges: Set<String> = []
    @State private var showingApprovalConfirmation = false
    
    var allChangeKeys: [String] {
        var keys: [String] = []
        if suggestedChanges.name != nil { keys.append("name") }
        if suggestedChanges.assignedRoomID != nil { keys.append("room") }
        if suggestedChanges.lightType != nil { keys.append("lightType") }
        if suggestedChanges.preferredLightDirection != nil { keys.append("lightDirection") }
        if suggestedChanges.humidityPreference != nil { keys.append("humidity") }
        if suggestedChanges.generalNotes != nil { keys.append("notes") }
        if let careSteps = suggestedChanges.careSteps, !careSteps.isEmpty {
            keys.append("careSteps")
        }
        return keys
    }
    
    var suggestedSpace: (name: String, type: String)? {
        guard let spaceName = suggestedChanges.assignedRoomID else { return nil }
        
        if let room = dataStore.rooms.first(where: { $0.name == spaceName }) {
            return (room.name, "indoor")
        } else if let zone = dataStore.zones.first(where: { $0.name == spaceName }) {
            return (zone.name, "outdoor")
        }
        return nil
    }
    
    var currentSpace: String {
        if let room = dataStore.roomForPlant(plant) {
            return room.name
        } else if let zone = dataStore.zoneForPlant(plant) {
            return zone.name
        }
        return "Not assigned"
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("AI has suggested the following changes for \(plant.name):")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack(spacing: 12) {
                        if let newName = suggestedChanges.name {
                            ChangeCard(
                                title: "Name",
                                current: plant.name,
                                suggested: newName,
                                isSelected: selectedChanges.contains("name"),
                                onToggle: { toggleChange("name") }
                            )
                        }
                        
                        if let spaceName = suggestedChanges.assignedRoomID {
                            let spaceType = suggestedSpace?.type ?? "unknown"
                            ChangeCard(
                                title: "Location",
                                current: currentSpace,
                                suggested: "\(spaceName)\(spaceType == "outdoor" ? " (Outdoor)" : "")",
                                isSelected: selectedChanges.contains("room"),
                                onToggle: { toggleChange("room") },
                                warning: suggestedSpace == nil ? "Space '\(spaceName)' not found" : nil
                            )
                        }
                        
                        if let lightType = suggestedChanges.lightType {
                            ChangeCard(
                                title: "Light Type",
                                current: plant.lightType.rawValue,
                                suggested: lightType.rawValue,
                                isSelected: selectedChanges.contains("lightType"),
                                onToggle: { toggleChange("lightType") }
                            )
                        }
                        
                        if let direction = suggestedChanges.preferredLightDirection {
                            ChangeCard(
                                title: "Preferred Light Direction",
                                current: plant.preferredLightDirection.rawValue,
                                suggested: direction.rawValue,
                                isSelected: selectedChanges.contains("lightDirection"),
                                onToggle: { toggleChange("lightDirection") }
                            )
                        }
                        
                        if let humidity = suggestedChanges.humidityPreference {
                            ChangeCard(
                                title: "Humidity Preference",
                                current: plant.humidityPreference?.rawValue ?? "Not specified",
                                suggested: humidity.rawValue,
                                isSelected: selectedChanges.contains("humidity"),
                                onToggle: { toggleChange("humidity") }
                            )
                        }
                        
                        if let notes = suggestedChanges.generalNotes {
                            ChangeCard(
                                title: "General Notes",
                                current: plant.generalNotes.isEmpty ? "No notes" : plant.generalNotes,
                                suggested: notes,
                                isSelected: selectedChanges.contains("notes"),
                                onToggle: { toggleChange("notes") },
                                isLongText: true
                            )
                        }
                        
                        if let careSteps = suggestedChanges.careSteps, !careSteps.isEmpty {
                            CareStepsChangeCard(
                                currentSteps: plant.careSteps,
                                suggestedSteps: careSteps,
                                isSelected: selectedChanges.contains("careSteps"),
                                onToggle: { toggleChange("careSteps") }
                            )
                        }
                    }
                    .padding(.horizontal)
                    
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            Button(action: selectAll) {
                                HStack {
                                    Image(systemName: "checkmark.square")
                                    Text("Select All")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemGray5))
                                .foregroundColor(.primary)
                                .cornerRadius(8)
                            }
                            
                            Button(action: deselectAll) {
                                HStack {
                                    Image(systemName: "square")
                                    Text("Deselect All")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemGray5))
                                .foregroundColor(.primary)
                                .cornerRadius(8)
                            }
                        }
                        
                        Button(action: { showingApprovalConfirmation = true }) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Apply Selected Changes")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(selectedChanges.isEmpty ? Color(.systemGray5) : Color.blue)
                            .foregroundColor(selectedChanges.isEmpty ? Color(.systemGray) : .white)
                            .cornerRadius(8)
                        }
                        .disabled(selectedChanges.isEmpty)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Review Changes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Apply Changes?", isPresented: $showingApprovalConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Apply") {
                    applySelectedChanges()
                }
            } message: {
                Text("Are you sure you want to apply the selected changes to \(plant.name)?")
            }
            .onAppear {
                // Auto-select all valid changes
                selectedChanges = Set(allChangeKeys.filter { key in
                    // Don't auto-select room changes if the room doesn't exist
                    if key == "room" && suggestedSpace == nil {
                        return false
                    }
                    return true
                })
            }
        }
    }
    
    func toggleChange(_ key: String) {
        if selectedChanges.contains(key) {
            selectedChanges.remove(key)
        } else {
            selectedChanges.insert(key)
        }
    }
    
    func selectAll() {
        selectedChanges = Set(allChangeKeys.filter { key in
            // Don't select room changes if the space doesn't exist
            if key == "room" && suggestedSpace == nil {
                return false
            }
            return true
        })
    }
    
    func deselectAll() {
        selectedChanges.removeAll()
    }
    
    func applySelectedChanges() {
        var updatedPlant = plant
        
        if selectedChanges.contains("name"), let newName = suggestedChanges.name {
            updatedPlant.name = newName
        }
        
        if selectedChanges.contains("room"), let space = suggestedSpace {
            if space.type == "indoor" {
                if let room = dataStore.rooms.first(where: { $0.name == space.name }) {
                    updatedPlant.assignedRoomID = room.id
                    updatedPlant.assignedZoneID = nil
                    // Auto-select window if room has only one
                    if room.windows.count == 1, let window = room.windows.first {
                        updatedPlant.assignedWindowID = window.id
                    } else {
                        // Clear window assignment when changing rooms with multiple windows
                        updatedPlant.assignedWindowID = nil
                    }
                }
            } else if space.type == "outdoor" {
                if let zone = dataStore.zones.first(where: { $0.name == space.name }) {
                    updatedPlant.assignedZoneID = zone.id
                    updatedPlant.assignedRoomID = nil
                    updatedPlant.assignedWindowID = nil
                }
            }
        }
        
        if selectedChanges.contains("lightType"), let lightType = suggestedChanges.lightType {
            updatedPlant.lightType = lightType
        }
        
        if selectedChanges.contains("lightDirection"), let direction = suggestedChanges.preferredLightDirection {
            updatedPlant.preferredLightDirection = direction
        }
        
        if selectedChanges.contains("humidity"), let humidity = suggestedChanges.humidityPreference {
            updatedPlant.humidityPreference = humidity
        }
        
        if selectedChanges.contains("notes"), let notes = suggestedChanges.generalNotes {
            updatedPlant.generalNotes = notes
        }
        
        if selectedChanges.contains("careSteps"), let suggestedSteps = suggestedChanges.careSteps {
            // Update existing care steps or add new ones
            for suggestion in suggestedSteps {
                if let existingIndex = updatedPlant.careSteps.firstIndex(where: { $0.type == suggestion.type }) {
                    // Update existing care step
                    var existingStep = updatedPlant.careSteps[existingIndex]
                    if let instructions = suggestion.instructions {
                        existingStep.instructions = instructions
                    }
                    if let frequency = suggestion.frequencyDays {
                        existingStep.frequencyDays = frequency
                    }
                    if suggestion.type == .custom, let customName = suggestion.customName {
                        existingStep.customName = customName
                    }
                    updatedPlant.careSteps[existingIndex] = existingStep
                } else {
                    // Add new care step
                    let newStep = CareStep(
                        type: suggestion.type,
                        customName: suggestion.customName,
                        instructions: suggestion.instructions ?? "",
                        frequencyDays: suggestion.frequencyDays ?? 7
                    )
                    updatedPlant.careSteps.append(newStep)
                }
            }
        }
        
        onApprove(updatedPlant)
        dismiss()
    }
}

struct ChangeCard: View {
    let title: String
    let current: String
    let suggested: String
    let isSelected: Bool
    let onToggle: () -> Void
    var warning: String? = nil
    var isLongText: Bool = false
    
    var body: some View {
        Button(action: onToggle) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(title)
                        .font(.headline)
                    
                    Spacer()
                    
                    Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                        .font(.title2)
                        .foregroundColor(isSelected ? .blue : .secondary)
                }
                
                if let warning = warning {
                    Label(warning, systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: isLongText ? .top : .center) {
                        Text("Current:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 60, alignment: .leading)
                        
                        Text(current)
                            .font(isLongText ? .caption : .subheadline)
                            .foregroundColor(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(isLongText ? nil : 1)
                    }
                    
                    HStack(alignment: isLongText ? .top : .center) {
                        Text("Suggested:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 60, alignment: .leading)
                        
                        Text(suggested)
                            .font(isLongText ? .caption : .subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(isLongText ? nil : 1)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(warning != nil)
    }
}

struct CareStepsChangeCard: View {
    let currentSteps: [CareStep]
    let suggestedSteps: [CareSuggestion]
    let isSelected: Bool
    let onToggle: () -> Void
    
    func isExistingStep(_ suggestion: CareSuggestion) -> Bool {
        currentSteps.contains { $0.type == suggestion.type }
    }
    
    func isLastSuggestion(_ suggestion: CareSuggestion) -> Bool {
        guard let lastSuggestion = suggestedSteps.last else { return false }
        return suggestion.type == lastSuggestion.type
    }
    
    var checkmarkImage: some View {
        Image(systemName: isSelected ? "checkmark.square.fill" : "square")
            .font(.title2)
            .foregroundColor(isSelected ? .blue : .secondary)
    }
    
    var stepsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(suggestedSteps, id: \.type) { suggestion in
                VStack(alignment: .leading, spacing: 4) {
                    CareStepSuggestionRow(
                        suggestion: suggestion,
                        isExisting: isExistingStep(suggestion)
                    )
                }
                .padding(.vertical, 4)
                
                if !isLastSuggestion(suggestion) {
                    Divider()
                }
            }
        }
        .padding(.horizontal, 8)
    }
    
    var body: some View {
        Button(action: onToggle) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Care Steps")
                        .font(.headline)
                    
                    Spacer()
                    
                    checkmarkImage
                }
                
                stepsList
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CareStepSuggestionRow: View {
    let suggestion: CareSuggestion
    let isExisting: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: suggestion.type.systemImageName)
                    .foregroundColor(.blue)
                    .frame(width: 20)
                
                Text(suggestion.customName ?? suggestion.type.rawValue)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(isExisting ? "(Update)" : "(New)")
                    .font(.caption)
                    .foregroundColor(isExisting ? .orange : .green)
            }
            
            if let instructions = suggestion.instructions {
                Text(instructions)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            if let frequency = suggestion.frequencyDays {
                Text("Every \(frequency) days")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
    }
}

#Preview {
    PlantChangeReviewView(
        plant: DataStore.shared.plants.first!,
        suggestedChanges: PlantChangeSuggestion(
            name: "Updated Plant Name",
            assignedRoomID: "Living Room",
            assignedWindowID: nil,
            lightType: LightType.indirect,
            preferredLightDirection: Direction.east,
            humidityPreference: HumidityPreference.high,
            generalNotes: "This plant needs more frequent watering in summer",
            careSteps: [
                CareSuggestion(type: CareStepType.watering, customName: nil, instructions: "Water thoroughly", frequencyDays: 5)
            ]
        ),
        onApprove: { _ in }
    )
    .environmentObject(DataStore.shared)
}