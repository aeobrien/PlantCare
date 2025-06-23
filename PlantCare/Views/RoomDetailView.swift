import SwiftUI

struct RoomDetailView: View {
    @EnvironmentObject var dataStore: DataStore
    @State var room: Room
    @State private var isEditing = false
    @State private var showingAddWindow = false
    @State private var newWindowDirection = Direction.north
    @State private var newWindowNotes = ""
    
    var plantsInRoom: [Plant] {
        dataStore.plantsInRoom(room)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Windows")
                            .font(.headline)
                        Spacer()
                        Button(action: {
                            showingAddWindow = true
                        }) {
                            Image(systemName: "plus.circle")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    ForEach(room.windows) { window in
                        WindowCard(window: window, room: room)
                    }
                    
                    if room.windows.isEmpty {
                        Text("No windows added yet")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Plants in this room")
                            .font(.headline)
                        Spacer()
                        Text("\(plantsInRoom.count)")
                            .foregroundColor(.secondary)
                    }
                    
                    if plantsInRoom.isEmpty {
                        Text("No plants assigned to this room")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    } else {
                        ForEach(plantsInRoom) { plant in
                            NavigationLink(destination: PlantDetailView(plant: plant)) {
                                PlantRow(plant: plant)
                            }
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle(room.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    isEditing = true
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            EditRoomView(room: $room)
        }
        .sheet(isPresented: $showingAddWindow) {
            AddWindowSheet(room: $room)
        }
    }
}

struct WindowCard: View {
    let window: Window
    let room: Room
    @EnvironmentObject var dataStore: DataStore
    
    var plantsAtWindow: [Plant] {
        dataStore.plants.filter { 
            $0.assignedRoomID == room.id && $0.assignedWindowID == window.id 
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "window.ceiling")
                    .font(.title3)
                    .foregroundColor(.blue)
                Text(window.direction.rawValue)
                    .font(.headline)
                Spacer()
                Text("\(plantsAtWindow.count) plant\(plantsAtWindow.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let notes = window.notes, !notes.isEmpty {
                Text(notes)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if !plantsAtWindow.isEmpty {
                HStack(spacing: 4) {
                    ForEach(plantsAtWindow.prefix(3)) { plant in
                        Text(plant.name)
                            .font(.caption2)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.2))
                            .cornerRadius(4)
                    }
                    if plantsAtWindow.count > 3 {
                        Text("+\(plantsAtWindow.count - 3)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct PlantRow: View {
    let plant: Plant
    @EnvironmentObject var dataStore: DataStore
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(plant.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                HStack(spacing: 4) {
                    Image(systemName: "sun.max")
                        .font(.caption2)
                    Text(plant.lightType.rawValue)
                        .font(.caption)
                    if let window = dataStore.windowForPlant(plant) {
                        Text("• \(window.direction.rawValue)")
                            .font(.caption)
                    }
                }
                .foregroundColor(.secondary)
            }
            Spacer()
            if let wateringStep = plant.wateringStep,
               let lastCompleted = wateringStep.lastCompletedDate {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Watered")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(lastCompleted, style: .relative)
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            } else if plant.hasAnyOverdueCareSteps {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Care needed")
                        .font(.caption2)
                        .foregroundColor(.red)
                        .fontWeight(.medium)
                }
            }
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct EditRoomView: View {
    @Binding var room: Room
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss
    @State private var roomName: String = ""
    @State private var windows: [Window] = []
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Room Information")) {
                    TextField("Room Name", text: $roomName)
                }
                
                Section(header: Text("Windows")) {
                    ForEach(windows) { window in
                        HStack {
                            Image(systemName: "window.ceiling")
                            Text(window.direction.rawValue)
                            if let notes = window.notes, !notes.isEmpty {
                                Text("- \(notes)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                    }
                    .onDelete(perform: deleteWindow)
                }
            }
            .navigationTitle("Edit Room")
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
                roomName = room.name
                windows = room.windows
            }
        }
    }
    
    func deleteWindow(at offsets: IndexSet) {
        windows.remove(atOffsets: offsets)
    }
    
    func saveChanges() {
        room.name = roomName
        room.windows = windows
        dataStore.updateRoom(room)
        dismiss()
    }
}

struct AddWindowSheet: View {
    @Binding var room: Room
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss
    @State private var selectedDirection = Direction.north
    @State private var notes = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Direction", selection: $selectedDirection) {
                        ForEach(Direction.allCases, id: \.self) { direction in
                            Text(direction.rawValue).tag(direction)
                        }
                    }
                    
                    TextField("Notes (optional)", text: $notes)
                }
            }
            .navigationTitle("Add Window")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addWindow()
                    }
                }
            }
        }
    }
    
    func addWindow() {
        let newWindow = Window(
            direction: selectedDirection,
            notes: notes.isEmpty ? nil : notes
        )
        room.windows.append(newWindow)
        dataStore.updateRoom(room)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        RoomDetailView(room: DataStore.shared.rooms.first!)
            .environmentObject(DataStore.shared)
    }
}