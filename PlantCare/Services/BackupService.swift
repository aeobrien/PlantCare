import Foundation
import UIKit
import os.log

struct BackupMetadata: Codable {
    let version: String = "1.0"
    let date: Date
    let deviceName: String
    let plantCount: Int
    let roomCount: Int
    let zoneCount: Int
    let photoCount: Int
}

struct BackupData: Codable {
    let metadata: BackupMetadata
    let rooms: [Room]
    let zones: [Zone]
    let plants: [Plant]
    let photos: [PlantPhoto]
    let settings: AppSettings
}

class BackupService: ObservableObject {
    static let shared = BackupService()
    
    @Published var availableBackups: [BackupInfo] = []
    @Published var isBackupInProgress = false
    @Published var isRestoreInProgress = false
    @Published var lastBackupDate: Date?
    @Published var iCloudAvailable = false
    
    private let containerURL: URL?
    private let backupDirectoryName = "PlantCareBackups"
    private let fileExtension = "plantcarebackup"
    private let logger = Logger(subsystem: "com.plantcare", category: "Backup")
    
    struct BackupInfo: Identifiable {
        let id = UUID()
        let url: URL
        let metadata: BackupMetadata
        let fileSize: Int64
    }
    
    init() {
        containerURL = FileManager.default.url(forUbiquityContainerIdentifier: nil)
        checkiCloudAvailability()
        
        if let lastBackup = UserDefaults.standard.object(forKey: "lastPlantCareBackupDate") as? Date {
            lastBackupDate = lastBackup
        }
        
        Task {
            await loadAvailableBackups()
        }
    }
    
    private func checkiCloudAvailability() {
        if let token = FileManager.default.ubiquityIdentityToken {
            iCloudAvailable = true
            logger.info("iCloud is available")
        } else {
            iCloudAvailable = false
            logger.warning("iCloud is not available")
        }
    }
    
    private var backupDirectory: URL? {
        guard let containerURL = containerURL else { return nil }
        return containerURL.appendingPathComponent("Documents").appendingPathComponent(backupDirectoryName)
    }
    
    func performBackup(dataStore: DataStore) async throws {
        guard iCloudAvailable else {
            throw BackupError.iCloudNotAvailable
        }
        
        await MainActor.run {
            isBackupInProgress = true
        }
        
        defer {
            Task { @MainActor in
                isBackupInProgress = false
            }
        }
        
        logger.info("Starting backup creation")
        
        // Create backup metadata
        let metadata = BackupMetadata(
            date: Date(),
            deviceName: UIDevice.current.name,
            plantCount: dataStore.plants.count,
            roomCount: dataStore.rooms.count,
            zoneCount: dataStore.zones.count,
            photoCount: dataStore.plantPhotos.count
        )
        
        let backupData = BackupData(
            metadata: metadata,
            rooms: dataStore.rooms,
            zones: dataStore.zones,
            plants: dataStore.plants,
            photos: dataStore.plantPhotos,
            settings: dataStore.settings
        )
        
        let fileName = "PlantCare_Backup_\(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short).replacingOccurrences(of: "/", with: "-").replacingOccurrences(of: ":", with: "-")).\(fileExtension)"
        
        guard let backupDir = backupDirectory else {
            throw BackupError.invalidDirectory
        }
        
        try FileManager.default.createDirectory(at: backupDir, withIntermediateDirectories: true)
        
        let fileURL = backupDir.appendingPathComponent(fileName)
        let document = PlantCareBackupDocument(fileURL: fileURL)
        document.backupData = backupData
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            document.save(to: fileURL, for: .forCreating) { success in
                if success {
                    self.logger.info("Backup saved successfully to: \(fileName)")
                    continuation.resume()
                } else {
                    self.logger.error("Failed to save backup")
                    continuation.resume(throwing: BackupError.saveFailed)
                }
            }
        }
        
        await MainActor.run {
            lastBackupDate = Date()
            UserDefaults.standard.set(lastBackupDate, forKey: "lastPlantCareBackupDate")
        }
        
        await loadAvailableBackups()
    }
    
    func restoreFromBackup(at url: URL, context dataStore: DataStore) async throws {
        guard iCloudAvailable else {
            throw BackupError.iCloudNotAvailable
        }
        
        await MainActor.run {
            isRestoreInProgress = true
        }
        
        defer {
            Task { @MainActor in
                isRestoreInProgress = false
            }
        }
        
        logger.info("Starting restore from backup: \(url.lastPathComponent)")
        
        let document = PlantCareBackupDocument(fileURL: url)
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            document.open { success in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: BackupError.openFailed)
                }
            }
        }
        
        guard let backupData = document.backupData else {
            throw BackupError.invalidData
        }
        
        // Restore photos first
        await restorePhotos(photos: backupData.photos)
        
        // Restore data
        await MainActor.run {
            dataStore.rooms = backupData.rooms
            dataStore.zones = backupData.zones
            dataStore.plants = backupData.plants
            dataStore.plantPhotos = backupData.photos
            dataStore.settings = backupData.settings
            dataStore.saveData()
        }
        
        document.close(completionHandler: nil)
        
        logger.info("Restore completed successfully")
    }
    
    private func restorePhotos(photos: [PlantPhoto]) async {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let localPhotosDir = documentsPath.appendingPathComponent("PlantPhotos")
        
        // Create local photos directory
        try? FileManager.default.createDirectory(at: localPhotosDir, withIntermediateDirectories: true)
        
        // Note: Photo restoration would require backing up photos to iCloud separately
        // For now, we'll just ensure the directory exists
    }
    
    func loadAvailableBackups() async {
        guard let backupDir = backupDirectory else { return }
        
        do {
            let fileManager = FileManager.default
            
            var isDirectory: ObjCBool = false
            guard fileManager.fileExists(atPath: backupDir.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                await MainActor.run {
                    availableBackups = []
                }
                return
            }
            
            let urls = try fileManager.contentsOfDirectory(at: backupDir, includingPropertiesForKeys: [.creationDateKey, .fileSizeKey])
            
            var backups: [BackupInfo] = []
            
            for url in urls where url.pathExtension == fileExtension {
                let document = PlantCareBackupDocument(fileURL: url)
                
                let opened = await withCheckedContinuation { continuation in
                    document.open { success in
                        continuation.resume(returning: success)
                    }
                }
                
                if opened, let data = document.backupData {
                    let attributes = try fileManager.attributesOfItem(atPath: url.path)
                    let fileSize = (attributes[.size] as? NSNumber)?.int64Value ?? 0
                    
                    backups.append(BackupInfo(
                        url: url,
                        metadata: data.metadata,
                        fileSize: fileSize
                    ))
                    
                    document.close(completionHandler: nil)
                }
            }
            
            await MainActor.run {
                availableBackups = backups.sorted { $0.metadata.date > $1.metadata.date }
            }
            
        } catch {
            logger.error("Error loading backups: \(error)")
        }
    }
    
    func deleteBackup(at url: URL) async throws {
        try FileManager.default.removeItem(at: url)
        await loadAvailableBackups()
    }
    
    func scheduleAutomaticBackup() {
        let lastBackup = lastBackupDate ?? Date.distantPast
        let hoursSinceLastBackup = Date().timeIntervalSince(lastBackup) / 3600
        
        if hoursSinceLastBackup >= 24 {
            Task {
                do {
                    try await performBackup(dataStore: DataStore.shared)
                } catch {
                    self.logger.error("Automatic backup failed: \(error)")
                }
            }
        }
    }
}

enum BackupError: LocalizedError {
    case iCloudNotAvailable
    case invalidDirectory
    case saveFailed
    case openFailed
    case invalidData
    
    var errorDescription: String? {
        switch self {
        case .iCloudNotAvailable:
            return "iCloud is not available. Please check your iCloud settings."
        case .invalidDirectory:
            return "Could not access iCloud backup directory."
        case .saveFailed:
            return "Failed to save backup to iCloud."
        case .openFailed:
            return "Failed to open backup file."
        case .invalidData:
            return "Backup file contains invalid data."
        }
    }
}