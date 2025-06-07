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
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataStore)
        }
    }
}
