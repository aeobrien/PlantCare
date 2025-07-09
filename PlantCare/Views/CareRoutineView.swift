import SwiftUI

struct CareRoutineView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss
    @State private var currentRoomIndex = 0
    @State private var completedCareSteps: Set<String> = []
    @State private var showingCompletion = false
    
    var sortedRooms: [Room] {
        dataStore.orderedRoomsForCareRoutine()
    }
    
    var currentRoom: Room? {
        guard currentRoomIndex < sortedRooms.count else { return nil }
        return sortedRooms[currentRoomIndex]
    }
    
    var plantsInCurrentRoom: [Plant] {
        guard let room = currentRoom else { return [] }
        return dataStore.plantsInRoom(room)
    }
    
    var totalCareSteps: Int {
        sortedRooms.reduce(0) { total, room in
            total + dataStore.plantsInRoom(room).reduce(0) { plantTotal, plant in
                plantTotal + plant.enabledCareSteps.count
            }
        }
    }
    
    func careStepKey(plantID: UUID, careStepID: UUID) -> String {
        return "\(plantID.uuidString)-\(careStepID.uuidString)"
    }
    
    var body: some View {
        NavigationStack {
            if sortedRooms.isEmpty {
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
            } else if let room = currentRoom {
                VStack(spacing: 0) {
                    ProgressHeader(
                        currentRoom: currentRoomIndex + 1,
                        totalRooms: sortedRooms.count,
                        completedCareSteps: completedCareSteps.count,
                        totalCareSteps: totalCareSteps
                    )
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            RoomHeader(room: room)
                            
                            VStack(spacing: 12) {
                                ForEach(plantsInCurrentRoom) { plant in
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
                        canGoBack: currentRoomIndex > 0,
                        canGoNext: currentRoomIndex < sortedRooms.count - 1,
                        onBack: previousRoom,
                        onNext: nextRoom,
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
    
    func previousRoom() {
        withAnimation {
            currentRoomIndex = max(0, currentRoomIndex - 1)
        }
    }
    
    func nextRoom() {
        withAnimation {
            currentRoomIndex = min(sortedRooms.count - 1, currentRoomIndex + 1)
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
            
            Text("Add plants to your rooms to start your care routine")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
    }
}

struct ProgressHeader: View {
    let currentRoom: Int
    let totalRooms: Int
    let completedCareSteps: Int
    let totalCareSteps: Int
    
    var progress: Double {
        totalCareSteps > 0 ? Double(completedCareSteps) / Double(totalCareSteps) : 0
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Room \(currentRoom) of \(totalRooms)")
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

struct RoomHeader: View {
    let room: Room
    @EnvironmentObject var dataStore: DataStore
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(room.name)
                .font(.largeTitle)
                .fontWeight(.bold)
            
            HStack {
                Label("\(dataStore.plantsInRoom(room).count) plants", systemImage: "leaf")
                Text("•")
                Label("\(room.windows.count) windows", systemImage: "window.ceiling")
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
    
    var window: Window? {
        dataStore.windowForPlant(plant)
    }
    
    func careStepKey(careStepID: UUID) -> String {
        return "\(plant.id.uuidString)-\(careStepID.uuidString)"
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PlantHeader(plant: plant, window: window, showingAIQuestion: $showingAIQuestion)
            
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
    }
}

struct PlantHeader: View {
    let plant: Plant
    let window: Window?
    @Binding var showingAIQuestion: Bool
    
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