import SwiftUI
import UIKit

struct CareRoutineView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss
    @SceneStorage("careRoutine.currentSpaceIndex") private var currentSpaceIndex = 0
    @SceneStorage("careRoutine.completedCareSteps") private var completedCareStepsData = Data()
    @SceneStorage("careRoutine.plantsWithPhotos") private var plantsWithPhotosData = Data()
    @SceneStorage("careRoutine.isActive") private var wasRoutineActive = false
    @State private var completedCareSteps: Set<String> = []
    @State private var showingCompletion = false
    @State private var plantsWithPhotos: Set<UUID> = []
    @State private var showingHealthCheck = false
    @State private var showingResumePrompt = false
    @State private var isRunningBackgroundHealthCheck = false
    
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
                plantTotal + plant.visibleCareStepsForRoutine(hideFutureDays: dataStore.settings.hideFutureCareStepsDays).count
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
                            // Clear persisted state immediately when completing
                            wasRoutineActive = false
                            completedCareStepsData = Data()
                            plantsWithPhotosData = Data()
                            currentSpaceIndex = 0
                            
                            if !plantsWithPhotos.isEmpty && dataStore.settings.openAIAPIKey.isEmpty == false && dataStore.settings.aiHealthCheckEnabled {
                                showingHealthCheck = true
                            } else {
                                endRoutine()
                            }
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
                                        hasPhoto: plantsWithPhotos.contains(plant.id),
                                        onToggleCareStep: { careStep in
                                            toggleCareStep(plant: plant, careStep: careStep)
                                        },
                                        onPhotoTaken: {
                                            plantsWithPhotos.insert(plant.id)
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
            loadPersistedState()
            // Only show resume prompt if routine was active and not on completion screen
            if wasRoutineActive && !completedCareSteps.isEmpty && !showingCompletion && currentSpaceIndex < allSpaces.count {
                showingResumePrompt = true
            } else {
                // Start fresh routine
                completedCareSteps = []
                plantsWithPhotos = []
                currentSpaceIndex = 0
                dataStore.startCareSession()
                wasRoutineActive = true
            }
        }
        .onChange(of: completedCareSteps) {
            savePersistedState()
        }
        .onChange(of: plantsWithPhotos) {
            savePersistedState()
        }
        .onChange(of: currentSpaceIndex) {
            savePersistedState()
        }
        .alert("Resume Previous Session?", isPresented: $showingResumePrompt) {
            Button("Resume") {
                dataStore.startCareSession()
                // Restore completed steps to current session
                for stepKey in completedCareSteps {
                    let components = stepKey.split(separator: "-")
                    if components.count == 2,
                       let plantID = UUID(uuidString: String(components[0])),
                       let careStepID = UUID(uuidString: String(components[1])) {
                        dataStore.markCareStepCompleted(plantID: plantID, careStepID: careStepID)
                    }
                }
            }
            Button("Start New") {
                completedCareSteps = []
                plantsWithPhotos = []
                currentSpaceIndex = 0
                dataStore.startCareSession()
                wasRoutineActive = true
            }
        } message: {
            Text("You have an unfinished care routine. Would you like to continue where you left off?")
        }
        .sheet(isPresented: $showingHealthCheck) {
            BatchHealthCheckView(plantsWithPhotos: plantsWithPhotos)
                .environmentObject(dataStore)
                .onDisappear {
                    endRoutine()
                }
        }
        .sheet(isPresented: $isRunningBackgroundHealthCheck) {
            BatchHealthCheckView(plantsWithPhotos: plantsWithPhotos, isBackgroundMode: true)
                .environmentObject(dataStore)
                .onDisappear {
                    dismiss()
                }
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
        // Save current room progress before moving to next
        saveCurrentRoomProgress()
        
        withAnimation {
            currentSpaceIndex = min(allSpaces.count - 1, currentSpaceIndex + 1)
        }
    }
    
    func completeRoutine() {
        // Clear the routine active flag immediately when reaching completion screen
        wasRoutineActive = false
        savePersistedState()
        
        withAnimation {
            showingCompletion = true
        }
    }
    
    func cancelRoutine() {
        // Don't save any remaining progress when cancelling
        dataStore.endCareSession()
        // Clear persisted state
        wasRoutineActive = false
        completedCareStepsData = Data()
        plantsWithPhotosData = Data()
        currentSpaceIndex = 0
        dismiss()
    }
    
    func saveCurrentRoomProgress() {
        // Apply completed care steps from current room immediately
        if let session = dataStore.currentCareSession {
            let currentSpacePlantIDs = Set(plantsInCurrentSpace.map { $0.id })
            let currentSpaceCompletedSteps = session.completedCareSteps.filter { currentSpacePlantIDs.contains($0.plantID) }
            
            for completedStep in currentSpaceCompletedSteps {
                if let plantIndex = dataStore.plants.firstIndex(where: { $0.id == completedStep.plantID }) {
                    dataStore.plants[plantIndex].markCareStepCompleted(withId: completedStep.careStepID, date: completedStep.completedDate)
                }
            }
            
            if !currentSpaceCompletedSteps.isEmpty {
                dataStore.saveData()
            }
        }
    }
    
    func endRoutine() {
        // Save any remaining progress
        saveCurrentRoomProgress()
        dataStore.endCareSession()
        
        // Run background health checks if there are photos and AI is enabled
        if !plantsWithPhotos.isEmpty && dataStore.settings.openAIAPIKey.isEmpty == false && dataStore.settings.aiHealthCheckEnabled {
            isRunningBackgroundHealthCheck = true
        }
        
        // Clear all state completely
        completedCareSteps = []
        plantsWithPhotos = []
        currentSpaceIndex = 0
        wasRoutineActive = false
        completedCareStepsData = Data()
        plantsWithPhotosData = Data()
        showingCompletion = false
        
        // If not running background health check, dismiss immediately
        if !isRunningBackgroundHealthCheck {
            dismiss()
        }
    }
    
    func savePersistedState() {
        // Convert sets to arrays for encoding
        let stepsArray = Array(completedCareSteps)
        let photosArray = Array(plantsWithPhotos)
        
        if let stepsData = try? JSONEncoder().encode(stepsArray) {
            completedCareStepsData = stepsData
        }
        if let photosData = try? JSONEncoder().encode(photosArray) {
            plantsWithPhotosData = photosData
        }
    }
    
    func loadPersistedState() {
        // Load completed care steps
        if let stepsArray = try? JSONDecoder().decode([String].self, from: completedCareStepsData) {
            completedCareSteps = Set(stepsArray)
        }
        // Load plants with photos
        if let photosArray = try? JSONDecoder().decode([UUID].self, from: plantsWithPhotosData) {
            plantsWithPhotos = Set(photosArray)
        }
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
        totalSpaces > 0 ? Double(currentSpace - 1) / Double(totalSpaces) : 0
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
    let hasPhoto: Bool
    let onToggleCareStep: (CareStep) -> Void
    let onPhotoTaken: () -> Void
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
                hasPhoto: hasPhoto,
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
            
            // Show last health check feedback if available
            if let healthFeedback = plant.lastHealthCheckFeedback {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: "heart.text.square")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text("Health Check Feedback")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.blue)
                    }
                    Text(healthFeedback)
                        .font(.caption)
                        .foregroundColor(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
            
            VStack(spacing: 8) {
                ForEach(plant.visibleCareStepsForRoutine(hideFutureDays: dataStore.settings.hideFutureCareStepsDays)) { careStep in
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
        onPhotoTaken()
    }
}

struct PlantHeader: View {
    let plant: Plant
    let window: Window?
    let hasPhoto: Bool
    @Binding var showingAIQuestion: Bool
    @Binding var showingImagePicker: Bool
    @EnvironmentObject var dataStore: DataStore
    
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
                    ZStack {
                        Image(systemName: "camera")
                            .font(.title3)
                            .foregroundColor(.green)
                        
                        if hasPhoto {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.caption)
                                .foregroundColor(.white)
                                .background(Circle().fill(Color.green))
                                .offset(x: 10, y: -10)
                        }
                    }
                }
                
                if dataStore.settings.aiEnquiriesEnabled {
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