import SwiftUI

struct PlantHealthCheckView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss
    let plantsWithPhotos: Set<UUID>
    @State private var currentPlantIndex = 0
    @State private var healthCheckResults: [UUID: String] = [:]
    @State private var isLoading = false
    @State private var loadingPlantID: UUID?
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var completedChecks = Set<UUID>()
    
    var plantsToCheck: [Plant] {
        dataStore.plants.filter { plantsWithPhotos.contains($0.id) }
    }
    
    var currentPlant: Plant? {
        guard currentPlantIndex < plantsToCheck.count else { return nil }
        return plantsToCheck[currentPlantIndex]
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if plantsToCheck.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("No Photos Taken")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Take photos of your plants during the care routine to receive health feedback")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding()
                } else if let plant = currentPlant {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            ProgressView(value: Double(currentPlantIndex + 1), total: Double(plantsToCheck.count))
                                .padding(.horizontal)
                                .tint(.green)
                            
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
                                }
                                
                                Spacer()
                                
                                if completedChecks.contains(plant.id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.title)
                                        .foregroundColor(.green)
                                }
                            }
                            .padding(.horizontal)
                            
                            // Show last health check feedback if available
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
                            
                            if let feedback = healthCheckResults[plant.id] {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "sparkles")
                                            .foregroundColor(.blue)
                                        Text("AI Health Assessment")
                                            .font(.headline)
                                    }
                                    
                                    Text(feedback)
                                        .font(.body)
                                        .padding()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color(.systemGray6))
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
                                    Image(systemName: "leaf.circle")
                                        .font(.system(size: 50))
                                        .foregroundColor(.green)
                                    
                                    Button(action: {
                                        performHealthCheck(for: plant)
                                    }) {
                                        HStack {
                                            Image(systemName: "wand.and.stars")
                                            Text("Analyze Plant Health")
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                    }
                                    .padding(.horizontal)
                                    
                                    Text("Based on photos taken during care routine")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 20)
                            }
                        }
                        .padding(.vertical)
                    }
                    
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
                                .background(healthCheckResults[plant.id] != nil ? Color.blue : Color(.systemGray5))
                                .foregroundColor(healthCheckResults[plant.id] != nil ? .white : .primary)
                                .cornerRadius(8)
                            }
                        } else {
                            Button(action: {
                                saveAllFeedback()
                                dismiss()
                            }) {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Finish")
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
                }
            }
            .navigationTitle("Health Check")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Skip All") {
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
                // Get recent photos for this plant
                let recentPhotos = dataStore.photos(for: plant.id)
                    .prefix(3)
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