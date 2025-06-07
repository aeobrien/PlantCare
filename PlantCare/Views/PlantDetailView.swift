import SwiftUI

struct PlantDetailView: View {
    @EnvironmentObject var dataStore: DataStore
    @State var plant: Plant
    @State private var isEditing = false
    
    var room: Room? {
        dataStore.roomForPlant(plant)
    }
    
    var window: Window? {
        dataStore.windowForPlant(plant)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(title: "Location & Light")
                    
                    VStack(spacing: 12) {
                        InfoRow(
                            icon: "house",
                            label: "Room",
                            value: room?.name ?? "Not assigned",
                            isEmpty: room == nil
                        )
                        
                        if let window = window {
                            InfoRow(
                                icon: "window.ceiling",
                                label: "Window",
                                value: window.direction.rawValue
                            )
                        }
                        
                        InfoRow(
                            icon: lightIcon,
                            label: "Light Type",
                            value: plant.lightType.rawValue
                        )
                        
                        InfoRow(
                            icon: "location.north.line",
                            label: "Preferred Direction",
                            value: plant.preferredLightDirection.rawValue
                        )
                    }
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(title: "Watering")
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text(plant.wateringInstructions)
                            .font(.body)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        
                        if let frequency = plant.wateringFrequencyDays {
                            InfoRow(
                                icon: "drop",
                                label: "Frequency",
                                value: "Every \(frequency) days"
                            )
                        }
                        
                        if let lastWatered = plant.lastWateredDate {
                            InfoRow(
                                icon: "calendar",
                                label: "Last Watered",
                                value: lastWatered.formatted(date: .abbreviated, time: .omitted)
                            )
                            
                            if let frequency = plant.wateringFrequencyDays {
                                let nextWatering = lastWatered.addingTimeInterval(Double(frequency) * 24 * 60 * 60)
                                let daysUntilWatering = Calendar.current.dateComponents([.day], from: Date(), to: nextWatering).day ?? 0
                                
                                HStack {
                                    Image(systemName: "clock")
                                        .foregroundColor(.blue)
                                        .frame(width: 20)
                                    Text("Next Watering")
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    if daysUntilWatering <= 0 {
                                        Text("Due today")
                                            .foregroundColor(.blue)
                                            .fontWeight(.medium)
                                    } else if daysUntilWatering == 1 {
                                        Text("Tomorrow")
                                            .foregroundColor(.orange)
                                    } else {
                                        Text("In \(daysUntilWatering) days")
                                    }
                                }
                                .padding()
                                .background(
                                    daysUntilWatering <= 0 ? 
                                    Color.blue.opacity(0.1) : 
                                    Color(.systemGray6)
                                )
                                .cornerRadius(8)
                            }
                        }
                    }
                }
                
                if let humidity = plant.humidityPreference {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "Environment")
                        
                        InfoRow(
                            icon: "humidity",
                            label: "Humidity",
                            value: humidity.rawValue
                        )
                        
                        if let rotation = plant.rotationFrequency {
                            InfoRow(
                                icon: "arrow.clockwise",
                                label: "Rotation",
                                value: rotation
                            )
                        }
                    }
                }
                
                if !plant.generalNotes.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "General Notes")
                        
                        Text(plant.generalNotes)
                            .font(.body)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }
                
                Button(action: {
                    markAsWatered()
                }) {
                    HStack {
                        Image(systemName: "drop.fill")
                        Text("Mark as Watered")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .padding(.top)
            }
            .padding()
        }
        .navigationTitle(plant.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        isEditing = true
                    }) {
                        Label("Edit", systemImage: "pencil")
                    }
                    
                    Button(action: duplicatePlant) {
                        Label("Duplicate", systemImage: "doc.on.doc")
                    }
                } label: {
                    Text("Edit")
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            EditPlantView(plant: $plant)
        }
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
    
    func markAsWatered() {
        plant.lastWateredDate = Date()
        dataStore.updatePlant(plant)
    }
    
    func duplicatePlant() {
        var newPlant = plant
        newPlant.id = UUID()
        newPlant.name = "\(plant.name) (Copy)"
        newPlant.lastWateredDate = nil
        dataStore.addPlant(newPlant)
    }
}

struct SectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.primary)
    }
}

struct InfoRow: View {
    let icon: String
    let label: String
    let value: String
    var isEmpty: Bool = false
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(isEmpty ? .secondary : .blue)
                .frame(width: 20)
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .foregroundColor(isEmpty ? .secondary : .primary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct EditPlantView: View {
    @Binding var plant: Plant
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss
    
    @State private var plantName: String = ""
    @State private var selectedRoomID: UUID?
    @State private var selectedWindowID: UUID?
    @State private var preferredLightDirection: Direction = .east
    @State private var lightType: LightType = .indirect
    @State private var wateringInstructions: String = ""
    @State private var generalNotes: String = ""
    @State private var wateringFrequencyDays: Int = 7
    @State private var humidityPreference: HumidityPreference = .medium
    @State private var rotationFrequency: String = ""
    
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
            .navigationTitle("Edit Plant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                }
            }
            .onAppear {
                plantName = plant.name
                selectedRoomID = plant.assignedRoomID
                selectedWindowID = plant.assignedWindowID
                preferredLightDirection = plant.preferredLightDirection
                lightType = plant.lightType
                wateringInstructions = plant.wateringInstructions
                generalNotes = plant.generalNotes
                wateringFrequencyDays = plant.wateringFrequencyDays ?? 7
                humidityPreference = plant.humidityPreference ?? .medium
                rotationFrequency = plant.rotationFrequency ?? ""
            }
        }
    }
    
    func saveChanges() {
        plant.name = plantName
        plant.assignedRoomID = selectedRoomID
        plant.assignedWindowID = selectedWindowID
        plant.preferredLightDirection = preferredLightDirection
        plant.lightType = lightType
        plant.wateringInstructions = wateringInstructions
        plant.generalNotes = generalNotes
        plant.wateringFrequencyDays = wateringFrequencyDays
        plant.humidityPreference = humidityPreference
        plant.rotationFrequency = rotationFrequency.isEmpty ? nil : rotationFrequency
        
        dataStore.updatePlant(plant)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        PlantDetailView(plant: DataStore.shared.plants.first!)
            .environmentObject(DataStore.shared)
    }
}