import SwiftUI

struct SpacesListView: View {
    @EnvironmentObject var dataStore: DataStore
    @State private var showingAddSpace = false
    @State private var showingAddRoom = false
    @State private var showingAddZone = false
    @State private var editMode = EditMode.inactive
    
    var body: some View {
        List {
            Section("Indoor Spaces") {
                ForEach(dataStore.rooms) { room in
                    NavigationLink(destination: RoomDetailView(room: room)) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(room.name)
                                    .font(.headline)
                                Text("\(room.windows.count) window\(room.windows.count == 1 ? "" : "s"), \(dataStore.plantsInRoom(room).count) plant\(dataStore.plantsInRoom(room).count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onDelete { offsets in
                    dataStore.deleteRoom(at: offsets)
                }
                .onMove { source, destination in
                    dataStore.moveRoom(from: source, to: destination)
                }
                
                if editMode == .inactive {
                    Button(action: {
                        showingAddRoom = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                            Text("Add Indoor Space")
                                .foregroundColor(.blue)
                        }
                    }
                }
            }
            
            Section("Outdoor Zones") {
                ForEach(dataStore.zones) { zone in
                    NavigationLink(destination: ZoneDetailView(zone: zone)) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(zone.name)
                                    .font(.headline)
                                HStack(spacing: 12) {
                                    Label(zone.aspect.rawValue, systemImage: "building.2")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Label(zone.sunPeriod.rawValue + " sun", systemImage: "sun.max")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }
                                Text("\(dataStore.plantsInZone(zone).count) plant\(dataStore.plantsInZone(zone).count == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
                .onDelete { offsets in
                    dataStore.deleteZone(at: offsets)
                }
                .onMove { source, destination in
                    dataStore.moveZone(from: source, to: destination)
                }
                
                if editMode == .inactive {
                    Button(action: {
                        showingAddZone = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                            Text("Add Outdoor Zone")
                                .foregroundColor(.green)
                        }
                    }
                }
            }
        }
        .navigationTitle("Spaces")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            EditButton()
        }
        .environment(\.editMode, $editMode)
        .sheet(isPresented: $showingAddRoom) {
            AddRoomView()
        }
        .sheet(isPresented: $showingAddZone) {
            AddZoneView()
        }
    }
}

#Preview {
    NavigationStack {
        SpacesListView()
            .environmentObject(DataStore.shared)
    }
}