import SwiftUI

struct RoomsListView: View {
    @EnvironmentObject var dataStore: DataStore
    @State private var showingAddRoom = false
    @State private var editMode = EditMode.inactive
    
    var body: some View {
        List {
            ForEach(dataStore.rooms.sorted(by: { $0.orderIndex < $1.orderIndex })) { room in
                NavigationLink(destination: RoomDetailView(room: room)) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(room.name)
                                .font(.headline)
                            HStack {
                                Text("\(room.windows.count) window\(room.windows.count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("•")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text("\(dataStore.plantsInRoom(room).count) plant\(dataStore.plantsInRoom(room).count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        Spacer()
                        if editMode == .active {
                            Image(systemName: "line.3.horizontal")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .onDelete(perform: deleteRooms)
            .onMove(perform: moveRooms)
        }
        .navigationTitle("Rooms")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    showingAddRoom = true
                }) {
                    Image(systemName: "plus")
                }
            }
        }
        .environment(\.editMode, $editMode)
        .sheet(isPresented: $showingAddRoom) {
            AddRoomView()
        }
    }
    
    func deleteRooms(at offsets: IndexSet) {
        dataStore.deleteRoom(at: offsets)
    }
    
    func moveRooms(from source: IndexSet, to destination: Int) {
        dataStore.moveRoom(from: source, to: destination)
    }
}

struct AddRoomView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss
    @State private var roomName = ""
    @State private var windows: [Window] = []
    @State private var selectedDirection = Direction.north
    @State private var windowNotes = ""
    
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
                    
                    HStack {
                        Picker("Direction", selection: $selectedDirection) {
                            ForEach(Direction.allCases, id: \.self) { direction in
                                Text(direction.rawValue).tag(direction)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        
                        TextField("Notes (optional)", text: $windowNotes)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        Button(action: addWindow) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            .navigationTitle("Add Room")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveRoom()
                    }
                    .disabled(roomName.isEmpty || windows.isEmpty)
                }
            }
        }
    }
    
    func addWindow() {
        let window = Window(
            direction: selectedDirection,
            notes: windowNotes.isEmpty ? nil : windowNotes
        )
        windows.append(window)
        windowNotes = ""
    }
    
    func deleteWindow(at offsets: IndexSet) {
        windows.remove(atOffsets: offsets)
    }
    
    func saveRoom() {
        let newRoom = Room(
            name: roomName,
            windows: windows,
            orderIndex: dataStore.rooms.count
        )
        dataStore.addRoom(newRoom)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        RoomsListView()
            .environmentObject(DataStore.shared)
    }
}