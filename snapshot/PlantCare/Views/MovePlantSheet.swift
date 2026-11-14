import SwiftUI

struct MovePlantSheet: View {
    let plant: Plant
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedRoomID: UUID?
    @State private var selectedZoneID: UUID?
    @State private var selectedWindowID: UUID?
    @State private var isIndoor: Bool
    
    init(plant: Plant) {
        self.plant = plant
        _isIndoor = State(initialValue: plant.assignedRoomID != nil)
        _selectedRoomID = State(initialValue: plant.assignedRoomID)
        _selectedZoneID = State(initialValue: plant.assignedZoneID)
        _selectedWindowID = State(initialValue: plant.assignedWindowID)
    }
    
    var selectedRoom: Room? {
        guard let roomID = selectedRoomID else { return nil }
        return dataStore.rooms.first { $0.id == roomID }
    }
    
    var selectedZone: Zone? {
        guard let zoneID = selectedZoneID else { return nil }
        return dataStore.zones.first { $0.id == zoneID }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Move \(plant.name) to:")) {
                    Picker("Space Type", selection: $isIndoor) {
                        Text("Indoor").tag(true)
                        Text("Outdoor").tag(false)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: isIndoor) { newValue in
                        if newValue {
                            selectedZoneID = nil
                        } else {
                            selectedRoomID = nil
                            selectedWindowID = nil
                        }
                    }
                    
                    if isIndoor {
                        Picker("Indoor Space", selection: $selectedRoomID) {
                            Text("None").tag(nil as UUID?)
                            ForEach(dataStore.rooms.sorted(by: { $0.orderIndex < $1.orderIndex })) { room in
                                HStack {
                                    Text(room.name)
                                    if room.id == plant.assignedRoomID {
                                        Text("(current)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .tag(room.id as UUID?)
                            }
                        }
                        .onChange(of: selectedRoomID) { newRoomID in
                            // Auto-select window if room has only one
                            if let roomID = newRoomID,
                               let room = dataStore.rooms.first(where: { $0.id == roomID }),
                               room.windows.count == 1,
                               let window = room.windows.first {
                                selectedWindowID = window.id
                            } else if newRoomID == nil {
                                selectedWindowID = nil
                            }
                        }
                        
                        if let room = selectedRoom, !room.windows.isEmpty {
                            Picker("Window", selection: $selectedWindowID) {
                                Text("None").tag(nil as UUID?)
                                ForEach(room.windows) { window in
                                    HStack {
                                        Text(window.direction.rawValue)
                                        if window.id == plant.assignedWindowID {
                                            Text("(current)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    .tag(window.id as UUID?)
                                }
                            }
                        }
                    } else {
                        Picker("Outdoor Zone", selection: $selectedZoneID) {
                            Text("None").tag(nil as UUID?)
                            ForEach(dataStore.zones.sorted(by: { $0.orderIndex < $1.orderIndex })) { zone in
                                HStack {
                                    Text(zone.name)
                                    if zone.id == plant.assignedZoneID {
                                        Text("(current)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .tag(zone.id as UUID?)
                            }
                        }
                    }
                }
                
                if let room = selectedRoom {
                    Section(header: Text("Room Info")) {
                        HStack {
                            Text("Windows")
                            Spacer()
                            Text("\(room.windows.count)")
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Current Plants")
                            Spacer()
                            Text("\(dataStore.plantsInRoom(room).count)")
                                .foregroundColor(.secondary)
                        }
                    }
                } else if let zone = selectedZone {
                    Section(header: Text("Zone Info")) {
                        HStack {
                            Text("Aspect")
                            Spacer()
                            Text(zone.aspect.rawValue)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Sun Period")
                            Spacer()
                            Text(zone.sunPeriod.rawValue)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Wind")
                            Spacer()
                            Text(zone.wind.rawValue)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("Current Plants")
                            Spacer()
                            Text("\(dataStore.plantsInZone(zone).count)")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Move Plant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Move") {
                        movePlant()
                    }
                    .disabled(
                        (selectedRoomID == plant.assignedRoomID && 
                         selectedWindowID == plant.assignedWindowID &&
                         selectedZoneID == nil) ||
                        (selectedZoneID == plant.assignedZoneID &&
                         selectedRoomID == nil)
                    )
                }
            }
        }
    }
    
    func movePlant() {
        var updatedPlant = plant
        updatedPlant.assignedRoomID = selectedRoomID
        updatedPlant.assignedZoneID = selectedZoneID
        updatedPlant.assignedWindowID = selectedWindowID
        dataStore.updatePlant(updatedPlant)
        dismiss()
    }
}

#Preview {
    MovePlantSheet(plant: Plant(
        name: "Snake Plant",
        preferredLightDirection: .south,
        lightType: .direct,
        generalNotes: "Test plant"
    ))
    .environmentObject(DataStore.shared)
}