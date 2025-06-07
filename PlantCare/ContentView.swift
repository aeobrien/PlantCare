//
//  ContentView.swift
//  PlantCare
//
//  Created by Aidan O'Brien on 07/06/2025.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var dataStore: DataStore
    @State private var showingCareRoutine = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                VStack(spacing: 10) {
                    Image(systemName: "leaf.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.green)
                    
                    Text("Plant Minder")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Keep your plants happy and healthy")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
                
                VStack(spacing: 20) {
                    Button(action: {
                        showingCareRoutine = true
                    }) {
                        HStack {
                            Image(systemName: "drop.circle.fill")
                                .font(.title2)
                            Text("Start Care Routine")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    
                    NavigationLink(destination: RoomsListView()) {
                        HStack {
                            Image(systemName: "house.circle.fill")
                                .font(.title2)
                            Text("Rooms")
                                .font(.headline)
                            Spacer()
                            Text("\(dataStore.rooms.count)")
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    
                    NavigationLink(destination: PlantsListView()) {
                        HStack {
                            Image(systemName: "leaf.circle.fill")
                                .font(.title2)
                                .foregroundColor(.green)
                            Text("Plants")
                                .font(.headline)
                            Spacer()
                            Text("\(dataStore.plants.count)")
                                .foregroundColor(.secondary)
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                                .font(.caption)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
                
                if let lastWateredPlants = dataStore.plants.compactMap({ $0.lastWateredDate }).max() {
                    VStack {
                        Text("Last care session")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(lastWateredPlants, style: .relative)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom)
                }
            }
            .navigationBarHidden(true)
            .sheet(isPresented: $showingCareRoutine) {
                CareRoutineView()
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(DataStore.shared)
}
