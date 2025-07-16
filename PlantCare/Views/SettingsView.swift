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
                
                BackupSection()
                
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

struct BackupSection: View {
    @EnvironmentObject var dataStore: DataStore
    @ObservedObject var backupService = BackupService.shared
    @State private var showingBackupsList = false
    @State private var showingBackupError = false
    @State private var backupError: Error?
    
    var body: some View {
        Section(header: Text("iCloud Backup")) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("iCloud Status")
                            .font(.subheadline)
                        HStack {
                            Image(systemName: backupService.iCloudAvailable ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(backupService.iCloudAvailable ? .green : .red)
                                .font(.caption)
                            Text(backupService.iCloudAvailable ? "Available" : "Not Available")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    if backupService.isBackupInProgress {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                
                if let lastBackup = backupService.lastBackupDate {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                        Text("Last backup: \(lastBackup, format: .relative(presentation: .named))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack(spacing: 12) {
                    Button(action: {
                        performManualBackup()
                    }) {
                        HStack {
                            Image(systemName: "icloud.and.arrow.up")
                            Text("Backup Now")
                        }
                        .font(.subheadline)
                    }
                    .disabled(backupService.isBackupInProgress || !backupService.iCloudAvailable)
                    
                    Button(action: {
                        showingBackupsList = true
                    }) {
                        HStack {
                            Image(systemName: "clock.arrow.circlepath")
                            Text("View Backups")
                        }
                        .font(.subheadline)
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .sheet(isPresented: $showingBackupsList) {
            BackupsListView()
                .environmentObject(dataStore)
        }
        .alert("Backup Error", isPresented: $showingBackupError) {
            Button("OK", role: .cancel) {}
        } message: {
            if let error = backupError {
                Text(error.localizedDescription)
            }
        }
    }
    
    func performManualBackup() {
        Task {
            do {
                try await backupService.performBackup(dataStore: dataStore)
            } catch {
                await MainActor.run {
                    backupError = error
                    showingBackupError = true
                }
            }
        }
    }
}

struct BackupsListView: View {
    @EnvironmentObject var dataStore: DataStore
    @ObservedObject var backupService = BackupService.shared
    @Environment(\.dismiss) var dismiss
    @State private var showingRestoreConfirmation = false
    @State private var selectedBackup: BackupService.BackupInfo?
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            List {
                if backupService.availableBackups.isEmpty {
                    Text("No backups available")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 40)
                } else {
                    ForEach(backupService.availableBackups) { backup in
                        BackupRow(backup: backup) {
                            selectedBackup = backup
                            showingRestoreConfirmation = true
                        }
                    }
                    .onDelete(perform: deleteBackups)
                }
            }
            .navigationTitle("Backups")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                Task {
                    await backupService.loadAvailableBackups()
                }
            }
            .confirmationDialog("Restore Backup", isPresented: $showingRestoreConfirmation) {
                Button("Restore", role: .destructive) {
                    if let backup = selectedBackup {
                        restoreBackup(backup)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                if let backup = selectedBackup {
                    Text("Are you sure you want to restore this backup from \(backup.metadata.date, format: .dateTime)? This will replace all current data.")
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .overlay {
                if backupService.isRestoreInProgress {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 16) {
                            ProgressView()
                            Text("Restoring backup...")
                                .font(.headline)
                        }
                        .padding(24)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(radius: 8)
                    }
                }
            }
        }
    }
    
    func deleteBackups(at offsets: IndexSet) {
        Task {
            for index in offsets {
                let backup = backupService.availableBackups[index]
                try? await backupService.deleteBackup(at: backup.url)
            }
        }
    }
    
    func restoreBackup(_ backup: BackupService.BackupInfo) {
        Task {
            do {
                try await backupService.restoreFromBackup(at: backup.url, context: dataStore)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}

struct BackupRow: View {
    let backup: BackupService.BackupInfo
    let onRestore: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(backup.metadata.date, format: .dateTime)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Text(backup.metadata.deviceName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Restore") {
                    onRestore()
                }
                .font(.caption)
                .buttonStyle(.bordered)
            }
            
            HStack(spacing: 16) {
                Label("\(backup.metadata.plantCount)", systemImage: "leaf")
                Label("\(backup.metadata.roomCount)", systemImage: "house")
                Label("\(backup.metadata.zoneCount)", systemImage: "sun.max")
                Label("\(backup.metadata.photoCount)", systemImage: "photo")
                if backup.fileSize > 0 {
                    Text(formatFileSize(backup.fileSize))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .font(.caption2)
            .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

#Preview {
    SettingsView()
        .environmentObject(DataStore.shared)
}