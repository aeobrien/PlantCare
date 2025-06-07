import SwiftUI

struct PlantsListView: View {
    @EnvironmentObject var dataStore: DataStore
    @State private var showingAddPlant = false
    @State private var showingImport = false
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
                NavigationLink(destination: PlantDetailView(plant: plant)) {
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
    }
    
    func deletePlants(at offsets: IndexSet) {
        dataStore.deletePlant(at: offsets)
    }
    
    func duplicatePlant(_ plant: Plant) {
        var newPlant = plant
        newPlant.id = UUID()
        newPlant.name = "\(plant.name) (Copy)"
        newPlant.lastWateredDate = nil
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
            
            if let lastWatered = plant.lastWateredDate,
               let frequency = plant.wateringFrequencyDays {
                let nextWatering = lastWatered.addingTimeInterval(Double(frequency) * 24 * 60 * 60)
                let daysUntilWatering = Calendar.current.dateComponents([.day], from: Date(), to: nextWatering).day ?? 0
                
                VStack(alignment: .trailing, spacing: 2) {
                    if daysUntilWatering <= 0 {
                        Text("Water today")
                            .font(.caption)
                            .foregroundColor(.blue)
                            .fontWeight(.medium)
                    } else if daysUntilWatering == 1 {
                        Text("Water tomorrow")
                            .font(.caption)
                            .foregroundColor(.orange)
                    } else {
                        Text("Water in \(daysUntilWatering) days")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
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
    @State private var selectedWindowID: UUID?
    @State private var preferredLightDirection = Direction.east
    @State private var lightType = LightType.indirect
    @State private var wateringInstructions = ""
    @State private var generalNotes = ""
    @State private var wateringFrequencyDays = 7
    @State private var humidityPreference = HumidityPreference.medium
    @State private var rotationFrequency = ""
    
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
                    Picker("Room", selection: $selectedRoomID) {
                        Text("None").tag(nil as UUID?)
                        ForEach(dataStore.rooms.sorted(by: { $0.orderIndex < $1.orderIndex })) { room in
                            Text(room.name).tag(room.id as UUID?)
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
                }
                
                Section(header: Text("Care Instructions")) {
                    VStack(alignment: .leading) {
                        Text("Watering Instructions")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextEditor(text: $wateringInstructions)
                            .frame(height: 60)
                    }
                    
                    HStack {
                        Text("Watering Frequency")
                        Spacer()
                        Picker("", selection: $wateringFrequencyDays) {
                            ForEach([3, 5, 7, 10, 14, 21, 30], id: \.self) { days in
                                Text("\(days) days").tag(days)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                    
                    Picker("Humidity Preference", selection: $humidityPreference) {
                        ForEach(HumidityPreference.allCases, id: \.self) { pref in
                            Text(pref.rawValue).tag(pref)
                        }
                    }
                    
                    TextField("Rotation Frequency (optional)", text: $rotationFrequency)
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
                    .disabled(plantName.isEmpty || wateringInstructions.isEmpty)
                }
            }
        }
    }
    
    func savePlant() {
        let newPlant = Plant(
            name: plantName,
            assignedRoomID: selectedRoomID,
            assignedWindowID: selectedWindowID,
            preferredLightDirection: preferredLightDirection,
            lightType: lightType,
            wateringInstructions: wateringInstructions,
            generalNotes: generalNotes,
            lastWateredDate: nil,
            wateringFrequencyDays: wateringFrequencyDays,
            humidityPreference: humidityPreference,
            rotationFrequency: rotationFrequency.isEmpty ? nil : rotationFrequency
        )
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