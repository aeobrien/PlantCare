//
//  PlantCareApp.swift
//  PlantCare
//
//  Created by Aidan O'Brien on 07/06/2025.
//

import SwiftUI

@main
struct PlantCareApp: App {
    @StateObject private var dataStore = DataStore.shared
    @StateObject private var notificationManager = NotificationManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataStore)
                .environmentObject(notificationManager)
                .task {
                    await requestNotificationPermission()
                }
        }
    }
    
    private func requestNotificationPermission() async {
        let granted = await notificationManager.requestPermission()
        if granted {
            await MainActor.run {
                notificationManager.updateDailyReminders()
            }
        }
    }
}
