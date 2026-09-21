import SwiftUI

struct ForceHealthCheckView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss
    @State private var currentPlantIndex = 0
    @State private var healthCheckResults: [UUID: String] = [:]
    @State private var isLoading = false
    @State private var loadingPlantID: UUID?
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var completedChecks = Set<UUID>()
    @State private var skippedPlants = Set<UUID>()
    
    var plantsToCheck: [Plant] {
        dataStore.plants.filter { plant in
            // Only include plants that have at least one photo
            !dataStore.photos(for: plant.id).isEmpty
        }
    }
    
    var currentPlant: Plant? {
        guard currentPlantIndex < plantsToCheck.count else { return nil }
        return plantsToCheck[currentPlantIndex]
    }
    
    var progress: Double {
        guard !plantsToCheck.isEmpty else { return 0 }
        return Double(currentPlantIndex + 1) / Double(plantsToCheck.count)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if plantsToCheck.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("No Plants with Photos")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Take photos of your plants to enable health check analysis")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding()
                } else if let plant = currentPlant {
                    // Progress bar
                    VStack(spacing: 8) {
                        HStack {
                            Text("Plant \(currentPlantIndex + 1) of \(plantsToCheck.count)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Spacer()
                            
                            Text("\(completedChecks.count) analyzed")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        ProgressView(value: progress)
                            .tint(.green)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            // Plant info
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(plant.name)
                                            .font(.largeTitle)
                                            .fontWeight(.bold)
                                        
                                        if let latinName = plant.latinName {
                                            Text(latinName)
                                                .font(.subheadline)
                                                .italic()
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        if let room = dataStore.roomForPlant(plant) {
                                            Text("📍 \(room.name)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        } else if let zone = dataStore.zoneForPlant(plant) {
                                            Text("🌳 \(zone.name)")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    if completedChecks.contains(plant.id) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.title)
                                            .foregroundColor(.green)
                                    } else if skippedPlants.contains(plant.id) {
                                        Image(systemName: "forward.circle.fill")
                                            .font(.title)
                                            .foregroundColor(.orange)
                                    }
                                }
                                
                                // Show last photo
                                if let lastPhoto = dataStore.photos(for: plant.id).first,
                                   let url = lastPhoto.imageURL,
                                   let uiImage = UIImage(contentsOfFile: url.path) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Latest photo from \(lastPhoto.dateTaken.formatted(date: .abbreviated, time: .omitted))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(maxHeight: 200)
                                            .cornerRadius(8)
                                    }
                                }
                            }
                            .padding(.horizontal)
                            
                            // Previous feedback
                            if let lastFeedback = plant.lastHealthCheckFeedback,
                               let lastDate = plant.lastHealthCheckDate {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "clock")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text("Previous feedback (\(lastDate.formatted(date: .abbreviated, time: .omitted)))")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Text(lastFeedback)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                }
                                .padding(.horizontal)
                            }
                            
                            // New feedback
                            if let feedback = healthCheckResults[plant.id] {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "sparkles")
                                            .foregroundColor(.blue)
                                        Text("New Health Assessment")
                                            .font(.headline)
                                    }
                                    
                                    Text(feedback)
                                        .font(.body)
                                        .padding()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color.blue.opacity(0.1))
                                        .cornerRadius(8)
                                }
                                .padding(.horizontal)
                            } else if loadingPlantID == plant.id {
                                VStack(spacing: 16) {
                                    ProgressView()
                                        .scaleEffect(1.2)
                                    Text("Analyzing plant health...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 40)
                            } else {
                                VStack(spacing: 16) {
                                    Button(action: {
                                        performHealthCheck(for: plant)
                                    }) {
                                        HStack {
                                            Image(systemName: "wand.and.stars")
                                            Text("Analyze Health")
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                    }
                                    
                                    Button(action: {
                                        skipPlant()
                                    }) {
                                        Text("Skip This Plant")
                                            .font(.subheadline)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding(.vertical)
                    }
                    
                    // Navigation controls
                    HStack(spacing: 16) {
                        if currentPlantIndex > 0 {
                            Button(action: previousPlant) {
                                HStack {
                                    Image(systemName: "chevron.left")
                                    Text("Previous")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color(.systemGray5))
                                .foregroundColor(.primary)
                                .cornerRadius(8)
                            }
                        }
                        
                        if currentPlantIndex < plantsToCheck.count - 1 {
                            Button(action: nextPlant) {
                                HStack {
                                    Text("Next")
                                    Image(systemName: "chevron.right")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(healthCheckResults[plant.id] != nil || skippedPlants.contains(plant.id) ? Color.blue : Color(.systemGray5))
                                .foregroundColor(healthCheckResults[plant.id] != nil || skippedPlants.contains(plant.id) ? .white : .primary)
                                .cornerRadius(8)
                            }
                        } else {
                            Button(action: {
                                saveAllFeedback()
                                dismiss()
                            }) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Save & Finish")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                } else {
                    // Completion view
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        
                        Text("Health Check Complete")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Analyzed \(completedChecks.count) of \(plantsToCheck.count) plants")
                            .font(.body)
                            .foregroundColor(.secondary)
                        
                        Button(action: {
                            dismiss()
                        }) {
                            Text("Done")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .padding(.horizontal)
                    }
                    .padding()
                }
            }
            .navigationTitle("Health Check All Plants")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    func performHealthCheck(for plant: Plant) {
        guard !dataStore.settings.openAIAPIKey.isEmpty else {
            errorMessage = "Please configure your OpenAI API key in Settings"
            showingError = true
            return
        }
        
        loadingPlantID = plant.id
        
        Task {
            do {
                // Get most recent photo for this plant
                let recentPhotos = dataStore.photos(for: plant.id)
                    .prefix(1)
                    .compactMap { photo -> Data? in
                        guard let url = photo.imageURL,
                              let data = try? Data(contentsOf: url) else { return nil }
                        return data
                    }
                
                guard !recentPhotos.isEmpty else {
                    await MainActor.run {
                        errorMessage = "No photos found for this plant"
                        showingError = true
                        loadingPlantID = nil
                    }
                    return
                }
                
                let response = try await OpenAIService.shared.performPlantHealthCheck(
                    plantId: plant.id.uuidString,
                    plantName: plant.name,
                    recentPhotos: Array(recentPhotos),
                    apiKey: dataStore.settings.openAIAPIKey
                )
                
                await MainActor.run {
                    healthCheckResults[plant.id] = response.feedback
                    completedChecks.insert(plant.id)
                    loadingPlantID = nil
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showingError = true
                    loadingPlantID = nil
                }
            }
        }
    }
    
    func skipPlant() {
        if let plant = currentPlant {
            skippedPlants.insert(plant.id)
            nextPlant()
        }
    }
    
    func previousPlant() {
        withAnimation {
            currentPlantIndex = max(0, currentPlantIndex - 1)
        }
    }
    
    func nextPlant() {
        withAnimation {
            currentPlantIndex = min(plantsToCheck.count - 1, currentPlantIndex + 1)
        }
    }
    
    func saveAllFeedback() {
        for (plantID, feedback) in healthCheckResults {
            if let index = dataStore.plants.firstIndex(where: { $0.id == plantID }) {
                var plant = dataStore.plants[index]
                plant.lastHealthCheckFeedback = feedback
                plant.lastHealthCheckDate = Date()
                dataStore.updatePlant(plant)
            }
        }
    }
}