import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var dataStore: DataStore
    @State private var settings: AppSettings
    @State private var roomOrder: [Room] = []
    
    init() {
        self._settings = State(initialValue: DataStore.shared.settings)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("API Settings")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("OpenAI API Key")
                            .font(.subheadline)
                        
                        Text("Required for AI-powered plant recommendations")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        SecureField("Enter your API key", text: $settings.openAIAPIKey)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        if !settings.openAIAPIKey.isEmpty {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                Text("API key saved")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section(header: Text("Warning Settings")) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Early completion warning")
                            .font(.subheadline)
                        
                        Text("Show red warning when completing care steps more than \(settings.earlyWarningDays) days early")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text("Days")
                            Spacer()
                            Picker("Warning Days", selection: $settings.earlyWarningDays) {
                                ForEach(1...7, id: \.self) { days in
                                    Text("\(days)").tag(days)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section(header: Text("Care Routine Room Order")) {
                    Text("Drag to reorder rooms for care routines")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ForEach(roomOrder, id: \.id) { room in
                        HStack {
                            Image(systemName: "line.3.horizontal")
                                .foregroundColor(.secondary)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(room.name)
                                    .font(.subheadline)
                                
                                Text("\(dataStore.plantsInRoom(room).count) plants")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .onMove(perform: moveRooms)
                    
                    Button("Reset to Default Order") {
                        resetRoomOrder()
                    }
                    .foregroundColor(.blue)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .onAppear {
                loadCurrentSettings()
            }
            .onChange(of: settings.earlyWarningDays) { _ in
                saveSettings()
            }
            .onChange(of: settings.openAIAPIKey) { _ in
                saveSettings()
            }
        }
    }
    
    private func loadCurrentSettings() {
        settings = dataStore.settings
        
        // Load room order - use custom order if available, otherwise default
        if settings.customRoomOrder.isEmpty {
            roomOrder = dataStore.rooms
                .filter { dataStore.plantsInRoom($0).count > 0 }
                .sorted(by: { $0.orderIndex < $1.orderIndex })
        } else {
            var orderedRooms: [Room] = []
            
            // Add rooms in custom order
            for roomID in settings.customRoomOrder {
                if let room = dataStore.rooms.first(where: { $0.id == roomID }),
                   dataStore.plantsInRoom(room).count > 0 {
                    orderedRooms.append(room)
                }
            }
            
            // Add any remaining rooms
            let customOrderIDs = Set(settings.customRoomOrder)
            let remainingRooms = dataStore.rooms.filter { room in
                !customOrderIDs.contains(room.id) && dataStore.plantsInRoom(room).count > 0
            }.sorted(by: { $0.orderIndex < $1.orderIndex })
            
            orderedRooms.append(contentsOf: remainingRooms)
            roomOrder = orderedRooms
        }
    }
    
    private func moveRooms(from source: IndexSet, to destination: Int) {
        roomOrder.move(fromOffsets: source, toOffset: destination)
        
        // Update custom room order
        settings.customRoomOrder = roomOrder.map { $0.id }
        saveSettings()
    }
    
    private func resetRoomOrder() {
        settings.customRoomOrder = []
        saveSettings()
        loadCurrentSettings() // Reload to show default order
    }
    
    private func saveSettings() {
        dataStore.updateSettings(settings)
    }
}

#Preview {
    SettingsView()
        .environmentObject(DataStore.shared)
}