import SwiftUI

struct AddPlantsToSpaceView: View {
    let targetRoom: Room?
    let targetZone: Zone?
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedPlantIDs: Set<UUID> = []
    @State private var searchText = ""
    
    var targetSpaceName: String {
        if let room = targetRoom {
            return room.name
        } else if let zone = targetZone {
            return zone.name
        }
        return "Unknown"
    }
    
    var isTargetIndoor: Bool {
        return targetRoom != nil
    }
    
    var availablePlants: [Plant] {
        let plants = searchText.isEmpty ? dataStore.plants : dataStore.plants.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            ($0.latinName?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
        
        // Sort plants by name
        return plants.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
    
    var body: some View {
        NavigationStack {
            List(availablePlants) { plant in
                PlantSelectionRow(
                    plant: plant,
                    isSelected: selectedPlantIDs.contains(plant.id),
                    currentLocation: locationText(for: plant),
                    isCurrentLocation: isInTargetSpace(plant)
                ) {
                    if selectedPlantIDs.contains(plant.id) {
                        selectedPlantIDs.remove(plant.id)
                    } else {
                        selectedPlantIDs.insert(plant.id)
                    }
                }
                .disabled(isInTargetSpace(plant))
            }
            .searchable(text: $searchText, prompt: "Search plants")
            .navigationTitle("Add Plants to \(targetSpaceName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Move") {
                        movePlants()
                    }
                    .disabled(selectedPlantIDs.isEmpty)
                }
            }
        }
    }
    
    func locationText(for plant: Plant) -> String {
        if let room = dataStore.roomForPlant(plant) {
            if let windowID = plant.assignedWindowID,
               let window = room.windows.first(where: { $0.id == windowID }) {
                return "\(room.name) - \(window.direction.rawValue)"
            }
            return room.name
        } else if let zone = dataStore.zoneForPlant(plant) {
            return zone.name
        }
        return "Not assigned"
    }
    
    func isInTargetSpace(_ plant: Plant) -> Bool {
        if let targetRoom = targetRoom {
            return plant.assignedRoomID == targetRoom.id
        } else if let targetZone = targetZone {
            return plant.assignedZoneID == targetZone.id
        }
        return false
    }
    
    func movePlants() {
        for plantID in selectedPlantIDs {
            if let plant = dataStore.plants.first(where: { $0.id == plantID }) {
                var updatedPlant = plant
                
                if let targetRoom = targetRoom {
                    updatedPlant.assignedRoomID = targetRoom.id
                    updatedPlant.assignedZoneID = nil
                    // Auto-select window if room has only one
                    if targetRoom.windows.count == 1,
                       let window = targetRoom.windows.first {
                        updatedPlant.assignedWindowID = window.id
                    } else {
                        updatedPlant.assignedWindowID = nil
                    }
                } else if let targetZone = targetZone {
                    updatedPlant.assignedZoneID = targetZone.id
                    updatedPlant.assignedRoomID = nil
                    updatedPlant.assignedWindowID = nil
                }
                
                dataStore.updatePlant(updatedPlant)
            }
        }
        dismiss()
    }
}

struct PlantSelectionRow: View {
    let plant: Plant
    let isSelected: Bool
    let currentLocation: String
    let isCurrentLocation: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)
                    .imageScale(.large)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(plant.name)
                        .font(.headline)
                        .foregroundColor(isCurrentLocation ? .secondary : .primary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "location")
                            .font(.caption2)
                        Text(currentLocation)
                            .font(.caption)
                        if isCurrentLocation {
                            Text("(current)")
                                .font(.caption)
                                .italic()
                        }
                    }
                    .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    AddPlantsToSpaceView(
        targetRoom: Room(name: "Living Room", windows: [], orderIndex: 0),
        targetZone: nil
    )
    .environmentObject(DataStore.shared)
}