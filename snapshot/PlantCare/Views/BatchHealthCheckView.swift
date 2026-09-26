import SwiftUI

struct BatchHealthCheckView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss
    let plantsWithPhotos: Set<UUID>
    let isBackgroundMode: Bool
    @State private var healthCheckResults: [UUID: String] = [:]
    @State private var loadingPlants: Set<UUID> = []
    @State private var completedPlants: Set<UUID> = []
    @State private var failedPlants: Set<UUID> = []
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isProcessing = false
    
    init(plantsWithPhotos: Set<UUID>, isBackgroundMode: Bool = false) {
        self.plantsWithPhotos = plantsWithPhotos
        self.isBackgroundMode = isBackgroundMode
    }
    
    var plantsToCheck: [Plant] {
        dataStore.plants.filter { plantsWithPhotos.contains($0.id) }
    }
    
    var body: some View {
        if isBackgroundMode {
            // In background mode, just process without UI
            Color.clear
                .onAppear {
                    startBatchHealthCheck()
                }
                .onChange(of: isProcessing) {
                    if !isProcessing {
                        // When processing is done, save and dismiss
                        saveAllFeedback()
                        dismiss()
                    }
                }
        } else {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 20) {
                        // Progress header
                        VStack(spacing: 12) {
                            Text("Analyzing Plant Health")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            ProgressView(value: Double(completedPlants.count + failedPlants.count), total: Double(plantsToCheck.count))
                                .tint(.green)
                            
                            Text("\(completedPlants.count) of \(plantsToCheck.count) plants analyzed")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        .padding(.horizontal)
                        
                        // Results list
                        VStack(spacing: 12) {
                            ForEach(plantsToCheck) { plant in
                                PlantHealthResultCard(
                                    plant: plant,
                                    result: healthCheckResults[plant.id],
                                    isLoading: loadingPlants.contains(plant.id),
                                    hasFailed: failedPlants.contains(plant.id)
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
                .navigationTitle("Health Check Results")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            saveAllFeedback()
                            dismiss()
                        }
                        .disabled(isProcessing)
                    }
                }
                .onAppear {
                    startBatchHealthCheck()
                }
                .alert("Error", isPresented: $showingError) {
                    Button("OK") { }
                } message: {
                    Text(errorMessage)
                }
            }
        }
    }
    
    func startBatchHealthCheck() {
        guard !dataStore.settings.openAIAPIKey.isEmpty else {
            errorMessage = "Please configure your OpenAI API key in Settings"
            showingError = true
            return
        }
        
        isProcessing = true
        
        // Process all plants concurrently with a limit
        Task {
            await withTaskGroup(of: (UUID, Result<String, Error>).self) { group in
                for plant in plantsToCheck {
                    group.addTask { [plant] in
                        await performHealthCheck(for: plant)
                    }
                }
                
                // Collect results
                for await (plantID, result) in group {
                    await MainActor.run {
                        switch result {
                        case .success(let feedback):
                            healthCheckResults[plantID] = feedback
                            completedPlants.insert(plantID)
                            loadingPlants.remove(plantID)
                        case .failure:
                            failedPlants.insert(plantID)
                            loadingPlants.remove(plantID)
                        }
                    }
                }
            }
            
            await MainActor.run {
                isProcessing = false
            }
        }
    }
    
    func performHealthCheck(for plant: Plant) async -> (UUID, Result<String, Error>) {
        await MainActor.run {
            loadingPlants.insert(plant.id)
        }
        
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
                throw APIError.openAIError("No photos found for this plant")
            }
            
            let response = try await OpenAIService.shared.performPlantHealthCheck(
                plantId: plant.id.uuidString,
                plantName: plant.name,
                recentPhotos: Array(recentPhotos),
                apiKey: dataStore.settings.openAIAPIKey
            )
            
            return (plant.id, .success(response.feedback))
        } catch {
            return (plant.id, .failure(error))
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

struct PlantHealthResultCard: View {
    let plant: Plant
    let result: String?
    let isLoading: Bool
    let hasFailed: Bool
    @EnvironmentObject var dataStore: DataStore
    
    var room: Room? {
        dataStore.roomForPlant(plant)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Plant header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plant.name)
                        .font(.headline)
                    if let room = room {
                        Text(room.name)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                } else if hasFailed {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundColor(.red)
                } else if result != nil {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }
            
            // Result content
            if let result = result {
                Text(result)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            } else if hasFailed {
                Text("Failed to analyze this plant")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}