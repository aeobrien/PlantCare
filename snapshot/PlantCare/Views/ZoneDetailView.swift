import SwiftUI

struct ZoneDetailView: View {
    @EnvironmentObject var dataStore: DataStore
    let zone: Zone
    @State private var isEditingZone = false
    @State private var selectedPlant: Plant?
    @State private var showingMovePlant = false
    @State private var showingAddPlantsSheet = false
    
    var plants: [Plant] {
        dataStore.plantsInZone(zone)
    }
    
    var zoneDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Zone Details")
                .font(.headline)
                .padding(.horizontal)
            
            VStack(spacing: 12) {
                HStack {
                    Label("Aspect", systemImage: "building.2")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(zone.aspect.rawValue)
                }
                .padding(.horizontal)
                
                HStack {
                    Label("Sun Period", systemImage: "sun.max")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(zone.sunPeriod.rawValue)
                }
                .padding(.horizontal)
                
                HStack {
                    Label("Wind Exposure", systemImage: "wind")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(zone.wind.rawValue)
                }
                .padding(.horizontal)
                
                HStack {
                    Label("Sun Hours", systemImage: "clock")
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(zone.sunHours?.rawValue ?? zone.inferredSunHours.rawValue)
                    if zone.sunHours == nil {
                        Text("(estimated)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            .padding(.horizontal)
        }
    }
    
    var plantsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Plants in this zone")
                    .font(.headline)
                Spacer()
                Text("\(plants.count)")
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            
            if plants.isEmpty {
                Text("No plants assigned to this zone yet")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
            } else {
                ForEach(plants) { plant in
                    NavigationLink(destination: PlantDetailView(plantID: plant.id)) {
                        PlantRowView(plant: plant)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            if let index = dataStore.plants.firstIndex(where: { $0.id == plant.id }) {
                                dataStore.deletePlant(at: IndexSet(integer: index))
                            }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                        
                        Button {
                            selectedPlant = plant
                            showingMovePlant = true
                        } label: {
                            Label("Move", systemImage: "arrow.right.circle")
                        }
                        .tint(.blue)
                    }
                }
            }
            
            Button(action: { showingAddPlantsSheet = true }) {
                Label("Add/Move Plants Here", systemImage: "plus.circle")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor.opacity(0.1))
                    .foregroundColor(.accentColor)
                    .cornerRadius(8)
            }
            .padding(.horizontal)
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                zoneDetailsSection
                plantsSection
            }
            .padding(.vertical)
        }
        .navigationTitle(zone.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Edit") {
                    isEditingZone = true
                }
            }
        }
        .sheet(isPresented: $isEditingZone) {
            EditZoneView(zone: zone)
        }
        .sheet(item: $selectedPlant) { plant in
            MovePlantSheet(plant: plant)
        }
        .sheet(isPresented: $showingAddPlantsSheet) {
            AddPlantsToSpaceView(targetRoom: nil, targetZone: zone)
                .environmentObject(dataStore)
        }
    }
}

struct PlantRowView: View {
    let plant: Plant
    @EnvironmentObject var dataStore: DataStore
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(plant.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                if let nextStep = plant.nextDueCareStep {
                    HStack(spacing: 4) {
                        Image(systemName: nextStep.type.systemImageName)
                            .font(.caption)
                        Text(nextStep.displayName)
                            .font(.caption)
                        if let daysUntil = nextStep.daysUntilDue {
                            if daysUntil < 0 {
                                Text("• Overdue by \(abs(daysUntil)) day\(abs(daysUntil) == 1 ? "" : "s")")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            } else if daysUntil == 0 {
                                Text("• Due today")
                                    .font(.caption)
                                    .foregroundColor(.orange)
                            } else {
                                Text("• Due in \(daysUntil) day\(daysUntil == 1 ? "" : "s")")
                                    .font(.caption)
                            }
                        }
                    }
                    .foregroundColor(.secondary)
                }
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

#Preview {
    NavigationStack {
        ZoneDetailView(zone: Zone(
            name: "Front Patio",
            aspect: .southWall,
            sunPeriod: .all,
            wind: .sheltered,
            orderIndex: 0
        ))
        .environmentObject(DataStore.shared)
    }
}