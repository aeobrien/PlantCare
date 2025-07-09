import SwiftUI

struct PlantsListView: View {
    @EnvironmentObject var dataStore: DataStore
    @State private var showingAddPlant = false
    @State private var showingImport = false
    @State private var showingAIAdd = false
    @State private var searchText = ""
    
    var filteredPlants: [Plant] {
        if searchText.isEmpty {
            return dataStore.plants
        } else {
            return dataStore.plants.filter { 
                $0.name.localizedCaseInsensitiveContains(searchText) 
            }
        }
    }
    
    var body: some View {
        List {
            ForEach(filteredPlants) { plant in
                NavigationLink(destination: PlantDetailView(plantID: plant.id)) {
                    PlantListRow(plant: plant)
                }
                .swipeActions(edge: .leading) {
                    Button {
                        duplicatePlant(plant)
                    } label: {
                        Label("Duplicate", systemImage: "doc.on.doc")
                    }
                    .tint(.blue)
                }
            }
            .onDelete(perform: deletePlants)
        }
        .searchable(text: $searchText, prompt: "Search plants")
        .navigationTitle("Plants")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        showingAddPlant = true
                    }) {
                        Label("Add Plant", systemImage: "plus")
                    }
                    
                    Button(action: {
                        showingImport = true
                    }) {
                        Label("Import from Clipboard", systemImage: "doc.on.clipboard")
                    }
                    
                    Button(action: {
                        showingAIAdd = true
                    }) {
                        Label("Add via AI", systemImage: "sparkles")
                    }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddPlant) {
            AddPlantView()
        }
        .sheet(isPresented: $showingImport) {
            ImportPlantsView()
        }
        .sheet(isPresented: $showingAIAdd) {
            AIPlantAddView()
        }
    }
    
    func deletePlants(at offsets: IndexSet) {
        dataStore.deletePlant(at: offsets)
    }
    
    func duplicatePlant(_ plant: Plant) {
        var newPlant = plant
        newPlant.id = UUID()
        newPlant.name = "\(plant.name) (Copy)"
        // Reset last completed dates for all care steps
        for i in 0..<newPlant.careSteps.count {
            newPlant.careSteps[i].lastCompletedDate = nil
        }
        dataStore.addPlant(newPlant)
    }
}

struct PlantListRow: View {
    let plant: Plant
    @EnvironmentObject var dataStore: DataStore
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(plant.name)
                    .font(.headline)
                
                HStack(spacing: 8) {
                    HStack(spacing: 2) {
                        Image(systemName: lightIcon)
                            .font(.caption2)
                        Text(plant.lightType.rawValue)
                            .font(.caption)
                    }
                    
                    if let room = dataStore.roomForPlant(plant) {
                        Text("•")
                            .font(.caption)
                        HStack(spacing: 2) {
                            Image(systemName: "house")
                                .font(.caption2)
                            Text(room.name)
                                .font(.caption)
                        }
                    }
                }
                .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                if plant.hasAnyOverdueCareSteps {
                    Text("\(plant.overdueCareSteps.count) overdue")
                        .font(.caption)
                        .foregroundColor(.red)
                        .fontWeight(.medium)
                } else if let nextStep = plant.nextDueCareStep {
                    if let daysUntil = nextStep.daysUntilDue {
                        if daysUntil == 0 {
                            Text("\(nextStep.displayName) today")
                                .font(.caption)
                                .foregroundColor(.orange)
                                .fontWeight(.medium)
                        } else if daysUntil == 1 {
                            Text("\(nextStep.displayName) tomorrow")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("\(nextStep.displayName) in \(daysUntil)d")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                } else if plant.careSteps.isEmpty {
                    Text("No care steps")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    var lightIcon: String {
        switch plant.lightType {
        case .direct:
            return "sun.max.fill"
        case .indirect:
            return "sun.max"
        case .low:
            return "moon"
        }
    }
}

struct AddPlantView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss
    
    @State private var plantName = ""
    @State private var selectedRoomID: UUID?
    @State private var selectedZoneID: UUID?
    @State private var selectedWindowID: UUID?
    @State private var preferredLightDirection = Direction.east
    @State private var lightType = LightType.indirect
    @State private var generalNotes = ""
    @State private var humidityPreference = HumidityPreference.medium
    @State private var isIndoor = true
    
    var selectedRoom: Room? {
        guard let roomID = selectedRoomID else { return nil }
        return dataStore.rooms.first { $0.id == roomID }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Plant Information")) {
                    TextField("Plant Name", text: $plantName)
                    
                    Picker("Light Type", selection: $lightType) {
                        ForEach(LightType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    
                    Picker("Preferred Light Direction", selection: $preferredLightDirection) {
                        ForEach(Direction.allCases, id: \.self) { direction in
                            Text(direction.rawValue).tag(direction)
                        }
                    }
                }
                
                Section(header: Text("Location")) {
                    Picker("Space Type", selection: $isIndoor) {
                        Text("Indoor").tag(true)
                        Text("Outdoor").tag(false)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .onChange(of: isIndoor) { _ in
                        // Reset selections when switching
                        selectedRoomID = nil
                        selectedZoneID = nil
                        selectedWindowID = nil
                    }
                    
                    if isIndoor {
                        Picker("Indoor Space", selection: $selectedRoomID) {
                            Text("None").tag(nil as UUID?)
                            ForEach(dataStore.rooms.sorted(by: { $0.orderIndex < $1.orderIndex })) { room in
                                Text(room.name).tag(room.id as UUID?)
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
                                    Text(window.direction.rawValue).tag(window.id as UUID?)
                                }
                            }
                        }
                    } else {
                        Picker("Outdoor Zone", selection: $selectedZoneID) {
                            Text("None").tag(nil as UUID?)
                            ForEach(dataStore.zones.sorted(by: { $0.orderIndex < $1.orderIndex })) { zone in
                                Text(zone.name).tag(zone.id as UUID?)
                            }
                        }
                    }
                }
                
                Section(header: Text("Environment")) {
                    Picker("Humidity Preference", selection: $humidityPreference) {
                        ForEach(HumidityPreference.allCases, id: \.self) { pref in
                            Text(pref.rawValue).tag(pref)
                        }
                    }
                }
                
                Section(header: Text("General Notes")) {
                    TextEditor(text: $generalNotes)
                        .frame(height: 80)
                }
            }
            .navigationTitle("Add Plant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        savePlant()
                    }
                    .disabled(plantName.isEmpty)
                }
            }
        }
    }
    
    func savePlant() {
        var newPlant = Plant(
            name: plantName,
            assignedRoomID: selectedRoomID,
            assignedZoneID: selectedZoneID,
            assignedWindowID: selectedWindowID,
            preferredLightDirection: preferredLightDirection,
            lightType: lightType,
            generalNotes: generalNotes,
            humidityPreference: humidityPreference
        )
        
        // Add a default watering care step
        let defaultWateringStep = CareStep(
            type: .watering,
            instructions: "Water when soil feels dry",
            frequencyDays: 7
        )
        newPlant.addCareStep(defaultWateringStep)
        
        dataStore.addPlant(newPlant)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        PlantsListView()
            .environmentObject(DataStore.shared)
    }
}