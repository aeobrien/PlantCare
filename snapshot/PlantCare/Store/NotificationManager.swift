import Foundation
import UserNotifications

class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    func requestPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            )
            return granted
        } catch {
            print("Error requesting notification permission: \(error)")
            return false
        }
    }
    
    func scheduleDailyPlantCareReminders() {
        let center = UNUserNotificationCenter.current()
        
        // Cancel existing plant care notifications
        center.removePendingNotificationRequests(withIdentifiers: ["daily-plant-care-reminder"])
        
        // Get overdue care steps
        let overdueSteps = DataStore.shared.allOverdueCareSteps()
        
        guard !overdueSteps.isEmpty else {
            return // Don't schedule notifications if nothing is overdue
        }
        
        // Create notification content
        let content = UNMutableNotificationContent()
        content.title = "Plant Care Reminder"
        
        if overdueSteps.count == 1 {
            let (plant, step) = overdueSteps.first!
            content.body = "\(plant.name) needs \(step.displayName.lowercased())"
        } else {
            let plantCount = Set(overdueSteps.map { $0.0.id }).count
            if plantCount == 1 {
                let plantName = overdueSteps.first!.0.name
                content.body = "\(plantName) has \(overdueSteps.count) overdue care steps"
            } else {
                content.body = "\(plantCount) plants need care (\(overdueSteps.count) overdue steps)"
            }
        }
        
        content.sound = .default
        content.badge = NSNumber(value: overdueSteps.count)
        
        // Create date components for 9:30 AM
        var dateComponents = DateComponents()
        dateComponents.hour = 9
        dateComponents.minute = 30
        
        // Create trigger for daily at 9:30 AM
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        
        // Create request
        let request = UNNotificationRequest(
            identifier: "daily-plant-care-reminder",
            content: content,
            trigger: trigger
        )
        
        // Schedule notification
        center.add(request) { error in
            if let error = error {
                print("Error scheduling notification: \(error)")
            }
        }
    }
    
    func updateDailyReminders() {
        // This should be called whenever care steps are completed or plant data changes
        Task {
            await scheduleNotificationsIfPermissionGranted()
        }
    }
    
    @MainActor
    private func scheduleNotificationsIfPermissionGranted() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        
        if settings.authorizationStatus == .authorized {
            scheduleDailyPlantCareReminders()
        }
    }
    
    func cancelAllPlantCareNotifications() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["daily-plant-care-reminder"])
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationManager: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
    
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        // Handle notification tap
        // Could navigate to care routine or specific plant
        completionHandler()
    }
}