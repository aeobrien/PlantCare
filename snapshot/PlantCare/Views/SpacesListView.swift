import SwiftUI

struct SpacesListView: View {
    @EnvironmentObject var dataStore: DataStore
    @State private var showingAddSpace = false
    @State private var showingAddRoom = false
    @State private var showingAddZone = false
    @State private var editMode = EditMode.inactive
    @State private var sortOption = SpacesSortOption.nameAscending
    
    var sortedRooms: [Room] {
        switch sortOption {
        case .nameAscending:
            return dataStore.rooms.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .nameDescending:
            return dataStore.rooms.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
        case .mostPlants:
            return dataStore.rooms.sorted { dataStore.plantsInRoom($0).count > dataStore.plantsInRoom($1).count }
        case .fewestPlants:
            return dataStore.rooms.sorted { dataStore.plantsInRoom($0).count < dataStore.plantsInRoom($1).count }
        }
    }
    
    var sortedZones: [Zone] {
        switch sortOption {
        case .nameAscending:
            return dataStore.zones.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .nameDescending:
            return dataStore.zones.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
        case .mostPlants:
            return dataStore.zones.sorted { dataStore.plantsInZone($0).count > dataStore.plantsInZone($1).count }
        case .fewestPlants:
            return dataStore.zones.sorted { dataStore.plantsInZone($0).count < dataStore.plantsInZone($1).count }
        }
    }
    
    var body: some View {
        List {
            Section("Indoor Spaces") {
                ForEach(sortedRooms) { room in
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
                ForEach(sortedZones) { zone in
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
            ToolbarItem(placement: .navigationBarLeading) {
                Menu {
                    Picker("Sort By", selection: $sortOption) {
                        ForEach(SpacesSortOption.allCases, id: \.self) { option in
                            Label(option.rawValue, systemImage: option.systemImageName)
                                .tag(option)
                        }
                    }
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down.circle")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
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