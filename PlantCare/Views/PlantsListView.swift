import SwiftUI

struct PlantsListView: View {
    @EnvironmentObject var dataStore: DataStore
    @State private var showingAddPlant = false
    @State private var showingImport = false
    @State private var searchText = ""
    @State private var sortOption = PlantsSortOption.nameAscending
    
    var filteredPlants: [Plant] {
        let plants = searchText.isEmpty ? dataStore.plants : dataStore.plants.filter { 
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            ($0.latinName?.localizedCaseInsensitiveContains(searchText) ?? false)
        }
        return plants.sorted(by: sortOption, dataStore: dataStore)
    }
    
    var isGroupedBySpace: Bool {
        sortOption == .groupBySpaceAscending || sortOption == .groupBySpaceDescending
    }
    
    var groupedPlants: [(String, [Plant])] {
        if !isGroupedBySpace {
            return [("", filteredPlants)]
        }
        
        let grouped = Dictionary(grouping: filteredPlants) { plant in
            dataStore.spaceNameForPlant(plant)
        }
        
        return grouped.sorted { first, second in
            if sortOption == .groupBySpaceAscending {
                return first.key.localizedCaseInsensitiveCompare(second.key) == .orderedAscending
            } else {
                return first.key.localizedCaseInsensitiveCompare(second.key) == .orderedDescending
            }
        }
    }
    
    var body: some View {
        List {
            ForEach(groupedPlants, id: \.0) { spaceName, plants in
                if isGroupedBySpace {
                    Section(header: Text(spaceName)
                        .font(.headline)
                        .foregroundColor(.primary)) {
                        ForEach(plants) { plant in
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
                        .onDelete { offsets in
                            deletePlantsInGroup(plants: plants, at: offsets)
                        }
                    }
                } else {
                    ForEach(plants) { plant in
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
            }
        }
        .searchable(text: $searchText, prompt: "Search plants")
        .navigationTitle("Plants")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Menu {
                    Picker("Sort By", selection: $sortOption) {
                        ForEach(PlantsSortOption.allCases, id: \.self) { option in
                            Label(option.rawValue, systemImage: option.systemImageName)
                                .tag(option)
                        }
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down.circle")
                }
            }
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
        for offset in offsets {
            if let plant = filteredPlants[safe: offset] {
                dataStore.deletePlant(plant)
            }
        }
    }
    
    func deletePlantsInGroup(plants: [Plant], at offsets: IndexSet) {
        for offset in offsets {
            if let plant = plants[safe: offset] {
                dataStore.deletePlant(plant)
            }
        }
    }
    
    func duplicatePlant(_ plant: Plant) {
        // Check if the plant name already has a number at the end
        let pattern = #"^(.+?)\s*#(\d+)$"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        
        var baseName = plant.name
        var currentNumber = 0
        
        if let match = regex?.firstMatch(in: plant.name, options: [], range: NSRange(plant.name.startIndex..., in: plant.name)) {
            // Extract base name and current number
            if let baseRange = Range(match.range(at: 1), in: plant.name) {
                baseName = String(plant.name[baseRange])
            }
            if let numberRange = Range(match.range(at: 2), in: plant.name),
               let number = Int(plant.name[numberRange]) {
                currentNumber = number
            }
        }
        
        // If original doesn't have a number, update it to #1
        if currentNumber == 0 {
            var originalPlant = plant
            originalPlant.name = "\(baseName) #1"
            dataStore.updatePlant(originalPlant)
            currentNumber = 1
        }
        
        // Create new plant with incremented number
        var newPlant = plant
        newPlant.id = UUID()
        newPlant.name = "\(baseName) #\(currentNumber + 1)"
        
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
    var onPlantCreated: ((UUID) -> Void)? = nil
    
    @State private var plantName = ""
    @State private var latinName = ""
    @State private var visualDescription = ""
    @State private var selectedRoomID: UUID?
    @State private var selectedZoneID: UUID?
    @State private var selectedWindowID: UUID?
    @State private var preferredLightDirection = Direction.east
    @State private var lightType = LightType.indirect
    @State private var generalNotes = ""
    @State private var humidityPreference = HumidityPreference.medium
    @State private var isIndoor = true
    @State private var showingAIAdd = false
    
    var selectedRoom: Room? {
        guard let roomID = selectedRoomID else { return nil }
        return dataStore.rooms.first { $0.id == roomID }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Plant Information")) {
                    TextField("Plant Name", text: $plantName)
                    TextField("Latin Name (optional)", text: $latinName)
                    TextField("Visual Description (optional)", text: $visualDescription, axis: .vertical)
                        .lineLimit(2...4)
                    
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
                ToolbarItem(placement: .principal) {
                    Button(action: { showingAIAdd = true }) {
                        Label("Add via AI", systemImage: "sparkles")
                            .labelStyle(.titleAndIcon)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        savePlant()
                    }
                    .disabled(plantName.isEmpty)
                }
            }
            .sheet(isPresented: $showingAIAdd) {
                AIPlantAddView { plantID in
                    // Dismiss the AddPlantView first
                    dismiss()
                    // Then call the original completion handler if provided
                    if let onPlantCreated = onPlantCreated {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            onPlantCreated(plantID)
                        }
                    }
                }
            }
        }
    }
    
    func savePlant() {
        var newPlant = Plant(
            name: plantName,
            latinName: latinName.isEmpty ? nil : latinName,
            visualDescription: visualDescription.isEmpty ? nil : visualDescription,
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