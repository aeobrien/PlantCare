import SwiftUI
import UIKit

struct CareRoutineView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss
    @State private var currentSpaceIndex = 0
    @State private var completedCareSteps: Set<String> = []
    @State private var showingCompletion = false
    
    enum SpaceType {
        case room(Room)
        case zone(Zone)
        
        var name: String {
            switch self {
            case .room(let room): return room.name
            case .zone(let zone): return zone.name
            }
        }
        
        var isIndoor: Bool {
            switch self {
            case .room: return true
            case .zone: return false
            }
        }
    }
    
    var allSpaces: [SpaceType] {
        let roomSpaces = dataStore.orderedRoomsForCareRoutine()
            .filter { dataStore.plantsInRoom($0).count > 0 }
            .map { SpaceType.room($0) }
        let zoneSpaces = dataStore.zones
            .filter { dataStore.plantsInZone($0).count > 0 }
            .sorted(by: { $0.orderIndex < $1.orderIndex })
            .map { SpaceType.zone($0) }
        return roomSpaces + zoneSpaces
    }
    
    var currentSpace: SpaceType? {
        guard currentSpaceIndex < allSpaces.count else { return nil }
        return allSpaces[currentSpaceIndex]
    }
    
    var plantsInCurrentSpace: [Plant] {
        guard let space = currentSpace else { return [] }
        switch space {
        case .room(let room):
            return dataStore.plantsInRoom(room)
        case .zone(let zone):
            return dataStore.plantsInZone(zone)
        }
    }
    
    var totalCareSteps: Int {
        allSpaces.reduce(0) { total, space in
            let plants: [Plant]
            switch space {
            case .room(let room):
                plants = dataStore.plantsInRoom(room)
            case .zone(let zone):
                plants = dataStore.plantsInZone(zone)
            }
            return total + plants.reduce(0) { plantTotal, plant in
                plantTotal + plant.enabledCareSteps.count
            }
        }
    }
    
    func careStepKey(plantID: UUID, careStepID: UUID) -> String {
        return "\(plantID.uuidString)-\(careStepID.uuidString)"
    }
    
    var body: some View {
        NavigationStack {
            if allSpaces.isEmpty {
                EmptyRoutineView()
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Close") {
                                dismiss()
                            }
                        }
                    }
            } else if showingCompletion {
                CompletionView(
                    completedCount: completedCareSteps.count,
                    totalCount: totalCareSteps
                )
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            endRoutine()
                        }
                    }
                }
            } else if let space = currentSpace {
                VStack(spacing: 0) {
                    ProgressHeader(
                        currentSpace: currentSpaceIndex + 1,
                        totalSpaces: allSpaces.count,
                        completedCareSteps: completedCareSteps.count,
                        totalCareSteps: totalCareSteps
                    )
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            SpaceHeader(space: space)
                            
                            VStack(spacing: 12) {
                                ForEach(plantsInCurrentSpace) { plant in
                                    PlantCareSection(
                                        plant: plant,
                                        completedCareSteps: completedCareSteps,
                                        onToggleCareStep: { careStep in
                                            toggleCareStep(plant: plant, careStep: careStep)
                                        }
                                    )
                                }
                            }
                            .padding(.horizontal)
                        }
                        .padding(.vertical)
                    }
                    
                    NavigationControls(
                        canGoBack: currentSpaceIndex > 0,
                        canGoNext: currentSpaceIndex < allSpaces.count - 1,
                        onBack: previousSpace,
                        onNext: nextSpace,
                        onComplete: completeRoutine
                    )
                }
                .navigationTitle("Care Routine")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            cancelRoutine()
                        }
                    }
                }
            }
        }
        .onAppear {
            dataStore.startCareSession()
        }
    }
    
    func toggleCareStep(plant: Plant, careStep: CareStep) {
        let key = careStepKey(plantID: plant.id, careStepID: careStep.id)
        
        if completedCareSteps.contains(key) {
            completedCareSteps.remove(key)
            dataStore.unmarkCareStepCompleted(plantID: plant.id, careStepID: careStep.id)
        } else {
            completedCareSteps.insert(key)
            dataStore.markCareStepCompleted(plantID: plant.id, careStepID: careStep.id)
        }
    }
    
    func previousSpace() {
        withAnimation {
            currentSpaceIndex = max(0, currentSpaceIndex - 1)
        }
    }
    
    func nextSpace() {
        withAnimation {
            currentSpaceIndex = min(allSpaces.count - 1, currentSpaceIndex + 1)
        }
    }
    
    func completeRoutine() {
        withAnimation {
            showingCompletion = true
        }
    }
    
    func cancelRoutine() {
        dataStore.endCareSession()
        dismiss()
    }
    
    func endRoutine() {
        dataStore.endCareSession()
        dismiss()
    }
}

struct EmptyRoutineView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "leaf.circle")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("No Plants to Care For")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Add plants to your rooms or outdoor zones to start your care routine")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

struct ProgressHeader: View {
    let currentSpace: Int
    let totalSpaces: Int
    let completedCareSteps: Int
    let totalCareSteps: Int
    
    var progress: Double {
        totalCareSteps > 0 ? Double(completedCareSteps) / Double(totalCareSteps) : 0
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Space \(currentSpace) of \(totalSpaces)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(completedCareSteps) / \(totalCareSteps) care steps")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            ProgressView(value: progress)
                .tint(.green)
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

struct SpaceHeader: View {
    let space: CareRoutineView.SpaceType
    @EnvironmentObject var dataStore: DataStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(space.name)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                if !space.isIndoor {
                    Image(systemName: "sun.max")
                        .font(.title2)
                        .foregroundColor(.orange)
                }
            }
            
            HStack {
                switch space {
                case .room(let room):
                    Label("\(dataStore.plantsInRoom(room).count) plants", systemImage: "leaf")
                    Text("•")
                    Label("\(room.windows.count) windows", systemImage: "window.ceiling")
                case .zone(let zone):
                    Label("\(dataStore.plantsInZone(zone).count) plants", systemImage: "leaf")
                    Text("•")
                    Label(zone.aspect.rawValue, systemImage: "location")
                    Text("•")
                    Label(zone.sunPeriod.rawValue, systemImage: "sun.max")
                }
            }
            .font(.subheadline)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }
}

struct PlantCareSection: View {
    let plant: Plant
    let completedCareSteps: Set<String>
    let onToggleCareStep: (CareStep) -> Void
    @EnvironmentObject var dataStore: DataStore
    @State private var showingAIQuestion = false
    @State private var showingImagePicker = false
    @State private var capturedImage: UIImage?
    
    var window: Window? {
        dataStore.windowForPlant(plant)
    }
    
    func careStepKey(careStepID: UUID) -> String {
        return "\(plant.id.uuidString)-\(careStepID.uuidString)"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PlantHeader(
                plant: plant,
                window: window,
                showingAIQuestion: $showingAIQuestion,
                showingImagePicker: $showingImagePicker
            )
            
            // Show visual description if available
            if let visualDescription = plant.visualDescription, !visualDescription.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "eye")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(visualDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray5).opacity(0.5))
                .cornerRadius(8)
            }
            
            VStack(spacing: 8) {
                ForEach(plant.enabledCareSteps) { careStep in
                    CareStepCard(
                        careStep: careStep,
                        isCompleted: completedCareSteps.contains(careStepKey(careStepID: careStep.id)),
                        onToggle: { onToggleCareStep(careStep) }
                    )
                }
            }
            
            if !plant.generalNotes.isEmpty {
                Label(plant.generalNotes, systemImage: "note.text")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
        .sheet(isPresented: $showingAIQuestion) {
            AIPlantQuestionView(plant: plant)
                .environmentObject(dataStore)
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $capturedImage, sourceType: .camera)
                .onDisappear {
                    if let image = capturedImage {
                        savePhoto(image)
                        capturedImage = nil
                    }
                }
        }
    }
    
    func savePhoto(_ image: UIImage) {
        guard let imageData = image.jpegData(compressionQuality: 0.8) else { return }
        
        let photo = PlantPhoto(
            plantID: plant.id,
            dateTaken: Date(),
            fileName: "\(UUID().uuidString).jpg",
            notes: nil
        )
        
        dataStore.addPhoto(photo, imageData: imageData)
    }
}

struct PlantHeader: View {
    let plant: Plant
    let window: Window?
    @Binding var showingAIQuestion: Bool
    @Binding var showingImagePicker: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(plant.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if let window = window {
                    Text("\(window.direction.rawValue) window")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                if plant.hasAnyOverdueCareSteps {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.title3)
                }
                
                Button(action: {
                    showingImagePicker = true
                }) {
                    Image(systemName: "camera")
                        .font(.title3)
                        .foregroundColor(.green)
                }
                
                Button(action: {
                    showingAIQuestion = true
                }) {
                    Image(systemName: "sparkles")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
            }
        }
    }
}

struct CareStepCard: View {
    let careStep: CareStep
    let isCompleted: Bool
    let onToggle: () -> Void
    
    var statusText: String {
        if isCompleted {
            return "Completed"
        } else if careStep.isOverdue {
            if let daysSince = careStep.daysSinceLastCompleted {
                return "Overdue by \(daysSince - careStep.frequencyDays) days"
            }
            return "Overdue"
        } else if let daysUntil = careStep.daysUntilDue {
            if daysUntil == 0 {
                return "Due today"
            } else if daysUntil == 1 {
                return "Due tomorrow"
            } else {
                return "Due in \(daysUntil) days"
            }
        }
        return "Due today"
    }
    
    var statusColor: Color {
        if isCompleted {
            return .green
        } else if careStep.isOverdue {
            return .red
        } else if let daysUntil = careStep.daysUntilDue {
            if daysUntil == 0 {
                return .orange
            } else if daysUntil > DataStore.shared.settings.earlyWarningDays {
                return .red // Subtle warning for early completion
            }
        }
        return .secondary
    }
    
    var body: some View {
        Button(action: onToggle) {
            HStack {
                Image(systemName: careStep.type.systemImageName)
                    .foregroundColor(careStep.type == .watering ? .blue : .secondary)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(careStep.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Text(statusText)
                            .font(.caption)
                            .foregroundColor(statusColor)
                    }
                    
                    Text(careStep.instructions)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                
                Spacer()
                
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isCompleted ? .green : .secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isCompleted ? Color.green.opacity(0.1) : Color(.systemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isCompleted ? Color.green : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct NavigationControls: View {
    let canGoBack: Bool
    let canGoNext: Bool
    let onBack: () -> Void
    let onNext: () -> Void
    let onComplete: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            Button(action: onBack) {
                HStack {
                    Image(systemName: "chevron.left")
                    Text("Previous")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(canGoBack ? Color(.systemGray5) : Color(.systemGray6))
                .foregroundColor(canGoBack ? .primary : .secondary)
                .cornerRadius(8)
            }
            .disabled(!canGoBack)
            
            if canGoNext {
                Button(action: onNext) {
                    HStack {
                        Text("Next")
                        Image(systemName: "chevron.right")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            } else {
                Button(action: onComplete) {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Complete")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

struct CompletionView: View {
    let completedCount: Int
    let totalCount: Int
    
    var message: String {
        return "Well done on completing your plant care routine!"
    }
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: completedCount == totalCount ? "checkmark.seal.fill" : "leaf.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(completedCount == totalCount ? .green : .blue)
            
            VStack(spacing: 16) {
                Text("Care Session Complete")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("\(completedCount) of \(totalCount) care steps completed")
                    .font(.title3)
                    .foregroundColor(.secondary)
                
                Text(message)
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                    .padding(.horizontal)
            }
            
            Spacer()
            Spacer()
        }
        .padding()
    }
}

#Preview {
    CareRoutineView()
        .environmentObject(DataStore.shared)
}