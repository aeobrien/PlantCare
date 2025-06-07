import SwiftUI

struct CareRoutineView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss
    @State private var currentRoomIndex = 0
    @State private var completedPlantIDs: Set<UUID> = []
    @State private var showingCompletion = false
    
    var sortedRooms: [Room] {
        dataStore.rooms
            .filter { room in dataStore.plantsInRoom(room).count > 0 }
            .sorted(by: { $0.orderIndex < $1.orderIndex })
    }
    
    var currentRoom: Room? {
        guard currentRoomIndex < sortedRooms.count else { return nil }
        return sortedRooms[currentRoomIndex]
    }
    
    var plantsInCurrentRoom: [Plant] {
        guard let room = currentRoom else { return [] }
        return dataStore.plantsInRoom(room)
    }
    
    var totalPlants: Int {
        sortedRooms.reduce(0) { $0 + dataStore.plantsInRoom($1).count }
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
                    completedCount: completedPlantIDs.count,
                    totalCount: totalPlants
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
                        completedPlants: completedPlantIDs.count,
                        totalPlants: totalPlants
                    )
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            RoomHeader(room: room)
                            
                            VStack(spacing: 12) {
                                ForEach(plantsInCurrentRoom) { plant in
                                    PlantCareCard(
                                        plant: plant,
                                        isCompleted: completedPlantIDs.contains(plant.id),
                                        onToggle: { togglePlant(plant) }
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
    
    func togglePlant(_ plant: Plant) {
        if completedPlantIDs.contains(plant.id) {
            completedPlantIDs.remove(plant.id)
        } else {
            completedPlantIDs.insert(plant.id)
            dataStore.markPlantAsCaredFor(plantID: plant.id)
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
    let completedPlants: Int
    let totalPlants: Int
    
    var progress: Double {
        totalPlants > 0 ? Double(completedPlants) / Double(totalPlants) : 0
    }
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Room \(currentRoom) of \(totalRooms)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text("\(completedPlants) / \(totalPlants) plants")
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

struct PlantCareCard: View {
    let plant: Plant
    let isCompleted: Bool
    let onToggle: () -> Void
    @EnvironmentObject var dataStore: DataStore
    
    var window: Window? {
        dataStore.windowForPlant(plant)
    }
    
    var body: some View {
        Button(action: onToggle) {
            VStack(alignment: .leading, spacing: 12) {
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
                    
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(isCompleted ? .green : .secondary)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Label(plant.wateringInstructions, systemImage: "drop")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    if !plant.generalNotes.isEmpty {
                        Label(plant.generalNotes, systemImage: "note.text")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    
                    if let rotation = plant.rotationFrequency {
                        Label(rotation, systemImage: "arrow.clockwise")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isCompleted ? Color.green.opacity(0.1) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isCompleted ? Color.green : Color.clear, lineWidth: 2)
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
        if completedCount == totalCount {
            return "Perfect! You've cared for all your plants!"
        } else if completedCount > totalCount / 2 {
            return "Great job! You've cared for most of your plants."
        } else if completedCount > 0 {
            return "Good start! Don't forget to check on the remaining plants."
        } else {
            return "No plants were marked as cared for."
        }
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
                
                Text("\(completedCount) of \(totalCount) plants cared for")
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