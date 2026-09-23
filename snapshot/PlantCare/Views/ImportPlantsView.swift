import SwiftUI

struct ImportPlantsView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss
    
    @State private var clipboardContent = ""
    @State private var importedPlants: [ImportedPlant] = []
    @State private var roomMappings: [RoomMapping] = []
    @State private var showingRoomMapping = false
    @State private var currentMappingIndex = 0
    @State private var importError: String?
    @State private var showingError = false
    @State private var isProcessing = false
    
    var unmatchedRooms: [String] {
        let existingRoomNames = dataStore.rooms.map { $0.name.lowercased() }
        let importedRoomNames = Set(importedPlants.map { $0.room })
        
        return importedRoomNames.filter { roomName in
            !existingRoomNames.contains(roomName.lowercased())
        }.sorted()
    }
    
    var currentMapping: RoomMapping? {
        guard currentMappingIndex < roomMappings.count else { return nil }
        return roomMappings[currentMappingIndex]
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if importedPlants.isEmpty {
                    ImportInstructionsView(
                        clipboardContent: $clipboardContent,
                        onImport: parseClipboard
                    )
                } else if showingRoomMapping {
                    RoomMappingView(
                        mapping: currentMapping,
                        existingRooms: dataStore.rooms,
                        onUpdate: updateMapping,
                        onNext: nextMapping
                    )
                } else {
                    ImportSummaryView(
                        importedPlants: importedPlants,
                        roomMappings: roomMappings,
                        dataStore: dataStore,
                        onConfirm: performImport,
                        onCancel: resetImport
                    )
                }
            }
            .navigationTitle("Import Plants")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Import Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(importError ?? "Unknown error")
            }
            .overlay {
                if isProcessing {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView("Importing...")
                        .padding()
                        .background(Color(.systemBackground))
                        .cornerRadius(10)
                        .shadow(radius: 5)
                }
            }
        }
    }
    
    func parseClipboard() {
        isProcessing = true
        
        DispatchQueue.main.async {
            do {
                let data = clipboardContent.data(using: .utf8) ?? Data()
                let decoder = JSONDecoder()
                let plants = try decoder.decode([ImportedPlant].self, from: data)
                
                self.importedPlants = plants
                self.checkForUnmatchedRooms()
                self.isProcessing = false
            } catch {
                self.importError = "Invalid JSON format. Please check your clipboard content."
                self.showingError = true
                self.isProcessing = false
            }
        }
    }
    
    func checkForUnmatchedRooms() {
        let unmatched = unmatchedRooms
        if !unmatched.isEmpty {
            roomMappings = unmatched.map { RoomMapping(unmatchedRoom: $0) }
            showingRoomMapping = true
            currentMappingIndex = 0
        }
    }
    
    func updateMapping(roomID: UUID?, createNew: Bool) {
        guard currentMappingIndex < roomMappings.count else { return }
        roomMappings[currentMappingIndex].matchedRoomID = roomID
        roomMappings[currentMappingIndex].createNew = createNew
    }
    
    func nextMapping() {
        if currentMappingIndex < roomMappings.count - 1 {
            currentMappingIndex += 1
        } else {
            showingRoomMapping = false
        }
    }
    
    func performImport() {
        isProcessing = true
        
        // Create new rooms if needed
        for mapping in roomMappings where mapping.createNew {
            let newRoom = Room(
                name: mapping.unmatchedRoom,
                windows: [Window(direction: .north)], // Default window
                orderIndex: dataStore.rooms.count
            )
            dataStore.addRoom(newRoom)
            
            // Update mapping with new room ID
            if let index = roomMappings.firstIndex(where: { $0.unmatchedRoom == mapping.unmatchedRoom }) {
                roomMappings[index].matchedRoomID = newRoom.id
            }
        }
        
        // Import plants
        for importedPlant in importedPlants {
            let roomID = getRoomID(for: importedPlant.room)
            let windowID = getWindowID(for: importedPlant, roomID: roomID)
            
            let plant = importedPlant.toPlant(roomID: roomID, windowID: windowID)
            dataStore.addPlant(plant)
        }
        
        isProcessing = false
        dismiss()
    }
    
    func getRoomID(for roomName: String) -> UUID? {
        // Check if room exists with exact match
        if let room = dataStore.rooms.first(where: { $0.name.lowercased() == roomName.lowercased() }) {
            return room.id
        }
        
        // Check mappings
        if let mapping = roomMappings.first(where: { $0.unmatchedRoom == roomName }) {
            return mapping.matchedRoomID
        }
        
        return nil
    }
    
    func getWindowID(for plant: ImportedPlant, roomID: UUID?) -> UUID? {
        guard let roomID = roomID,
              let room = dataStore.rooms.first(where: { $0.id == roomID }) else { return nil }
        
        // Try to match window direction
        let direction = parseDirection(plant.windowDirection)
        if let window = room.windows.first(where: { $0.direction == direction }) {
            return window.id
        }
        
        // Return first window if no match
        return room.windows.first?.id
    }
    
    func parseDirection(_ directionString: String) -> Direction {
        switch directionString.lowercased() {
        case "north": return .north
        case "northeast": return .northeast
        case "east": return .east
        case "southeast": return .southeast
        case "south": return .south
        case "southwest": return .southwest
        case "west": return .west
        case "northwest": return .northwest
        default: return .north
        }
    }
    
    func resetImport() {
        importedPlants = []
        roomMappings = []
        clipboardContent = ""
        currentMappingIndex = 0
        showingRoomMapping = false
    }
}

struct ImportInstructionsView: View {
    @Binding var clipboardContent: String
    let onImport: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Import Plants from JSON")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Paste your JSON data below or copy it to your clipboard first")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("JSON Format:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("""
                [{
                  "name": "Plant Name",
                  "room": "Room Name",
                  "windowDirection": "northeast",
                  "preferredLightDirection": "east",
                  "lightType": "indirect",
                  "wateringInstructions": "Water weekly",
                  "careNotes": "Additional notes"
                }]
                """)
                .font(.system(.caption, design: .monospaced))
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            .padding(.horizontal)
            
            VStack(spacing: 12) {
                TextEditor(text: $clipboardContent)
                    .frame(height: 150)
                    .padding(4)
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                
                HStack(spacing: 12) {
                    Button(action: pasteFromClipboard) {
                        Label("Paste from Clipboard", systemImage: "doc.on.clipboard")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: onImport) {
                        Label("Import", systemImage: "square.and.arrow.down")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(clipboardContent.isEmpty)
                }
            }
            .padding(.horizontal)
            
            Spacer()
        }
        .padding(.top)
    }
    
    func pasteFromClipboard() {
        if let content = UIPasteboard.general.string {
            clipboardContent = content
        }
    }
}

struct RoomMappingView: View {
    let mapping: RoomMapping?
    let existingRooms: [Room]
    let onUpdate: (UUID?, Bool) -> Void
    let onNext: () -> Void
    
    @State private var selectedOption = "existing"
    @State private var selectedRoomID: UUID?
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                Image(systemName: "questionmark.circle")
                    .font(.system(size: 50))
                    .foregroundColor(.orange)
                
                Text("Unknown Room")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                if let mapping = mapping {
                    Text("The room \"\(mapping.unmatchedRoom)\" doesn't exist")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.top)
            
            VStack(alignment: .leading, spacing: 16) {
                Text("What would you like to do?")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 12) {
                    RadioButton(
                        isSelected: selectedOption == "existing",
                        label: "Map to existing room"
                    ) {
                        selectedOption = "existing"
                    }
                    
                    if selectedOption == "existing" {
                        Picker("Select Room", selection: $selectedRoomID) {
                            Text("Choose a room").tag(nil as UUID?)
                            ForEach(existingRooms.sorted(by: { $0.orderIndex < $1.orderIndex })) { room in
                                Text(room.name).tag(room.id as UUID?)
                            }
                        }
                        .pickerStyle(.menu)
                        .padding(.leading, 28)
                    }
                    
                    RadioButton(
                        isSelected: selectedOption == "new",
                        label: "Create new room \"\(mapping?.unmatchedRoom ?? "")\""
                    ) {
                        selectedOption = "new"
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal)
            
            Spacer()
            
            Button(action: {
                if selectedOption == "existing" {
                    onUpdate(selectedRoomID, false)
                } else {
                    onUpdate(nil, true)
                }
                onNext()
            }) {
                Text("Continue")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        (selectedOption == "existing" && selectedRoomID == nil) ?
                        Color.gray : Color.blue
                    )
                    .foregroundColor(.white)
                    .cornerRadius(8)
            }
            .disabled(selectedOption == "existing" && selectedRoomID == nil)
            .padding(.horizontal)
            .padding(.bottom)
        }
    }
}

struct RadioButton: View {
    let isSelected: Bool
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .secondary)
                Text(label)
                    .foregroundColor(.primary)
                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}

struct ImportSummaryView: View {
    let importedPlants: [ImportedPlant]
    let roomMappings: [RoomMapping]
    let dataStore: DataStore
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    var newRoomsCount: Int {
        roomMappings.filter { $0.createNew }.count
    }
    
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 50))
                    .foregroundColor(.green)
                
                Text("Ready to Import")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                VStack(spacing: 8) {
                    Text("\(importedPlants.count) plants will be imported")
                        .font(.body)
                    
                    if newRoomsCount > 0 {
                        Text("\(newRoomsCount) new room\(newRoomsCount == 1 ? "" : "s") will be created")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.top)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if !roomMappings.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Room Mappings")
                                .font(.headline)
                            
                            ForEach(roomMappings, id: \.unmatchedRoom) { mapping in
                                HStack {
                                    Text(mapping.unmatchedRoom)
                                    Image(systemName: "arrow.right")
                                        .font(.caption)
                                    if mapping.createNew {
                                        Label("New Room", systemImage: "plus.circle")
                                            .foregroundColor(.green)
                                    } else if let roomID = mapping.matchedRoomID,
                                              let room = dataStore.rooms.first(where: { $0.id == roomID }) {
                                        Text(room.name)
                                            .foregroundColor(.blue)
                                    }
                                }
                                .font(.subheadline)
                            }
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Plants to Import")
                            .font(.headline)
                        
                        ForEach(importedPlants, id: \.name) { plant in
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(plant.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                    Text(plant.room)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                Text(plant.lightType)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(4)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                .padding(.horizontal)
            }
            
            Spacer()
            
            HStack(spacing: 12) {
                Button(action: onCancel) {
                    Text("Back")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray5))
                        .foregroundColor(.primary)
                        .cornerRadius(8)
                }
                
                Button(action: onConfirm) {
                    Text("Import Plants")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }
}

#Preview {
    ImportPlantsView()
        .environmentObject(DataStore.shared)
}