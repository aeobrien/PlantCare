import SwiftUI

struct UpdateWateringInstructionsView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss
    
    @State private var isProcessing = false
    @State private var progress: Double = 0
    @State private var currentPlantName = ""
    @State private var processedCount = 0
    @State private var errorCount = 0
    @State private var errors: [String] = []
    @State private var showingResults = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if !isProcessing && !showingResults {
                    VStack(spacing: 16) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("Update Watering Instructions")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        VStack(spacing: 8) {
                            Text("This will update the watering instructions for all your plants to include:")
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Label("Specific indicators for when to water", systemImage: "1.circle.fill")
                                Label("Clear guidance on how much water to use", systemImage: "2.circle.fill")
                            }
                            .font(.footnote)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                        }
                        
                        Text("This process will use AI to analyze each plant and may take a few minutes.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Spacer()
                        
                        Button(action: startUpdate) {
                            Label("Start Update", systemImage: "arrow.clockwise")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                    .padding()
                } else if isProcessing {
                    VStack(spacing: 16) {
                        ProgressView(value: progress)
                            .progressViewStyle(LinearProgressViewStyle())
                        
                        if !currentPlantName.isEmpty {
                            Text("Updating: \(currentPlantName)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Text("\(processedCount) of \(dataStore.plants.count) plants processed")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                } else if showingResults {
                    ScrollView {
                        VStack(spacing: 16) {
                            Image(systemName: errorCount == 0 ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(errorCount == 0 ? .green : .orange)
                            
                            Text("Update Complete")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            VStack(spacing: 8) {
                                Label("\(processedCount - errorCount) plants updated successfully", systemImage: "checkmark.circle")
                                    .foregroundColor(.green)
                                
                                if errorCount > 0 {
                                    Label("\(errorCount) plants had errors", systemImage: "xmark.circle")
                                        .foregroundColor(.red)
                                }
                            }
                            
                            if !errors.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Errors:")
                                        .font(.headline)
                                    
                                    ForEach(errors, id: \.self) { error in
                                        Text("• \(error)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding()
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            }
                            
                            Button("Done") {
                                dismiss()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Update Watering")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isProcessing)
                }
            }
        }
    }
    
    private func startUpdate() {
        guard !dataStore.settings.openAIAPIKey.isEmpty else {
            errors.append("OpenAI API key is not configured")
            errorCount = 1
            showingResults = true
            return
        }
        
        isProcessing = true
        
        Task {
            let openAIService = OpenAIService.shared
            let totalPlants = dataStore.plants.count
            
            for (index, plant) in dataStore.plants.enumerated() {
                await MainActor.run {
                    currentPlantName = plant.name
                    progress = Double(index) / Double(totalPlants)
                }
                
                do {
                    let updatedInstructions = try await openAIService.updateWateringInstructions(for: plant, apiKey: dataStore.settings.openAIAPIKey)
                    
                    await MainActor.run {
                        var updatedPlant = plant
                        
                        // Find and update the watering care step
                        if let wateringIndex = updatedPlant.careSteps.firstIndex(where: { $0.type == .watering }) {
                            updatedPlant.careSteps[wateringIndex].instructions = updatedInstructions
                            dataStore.updatePlant(updatedPlant)
                        }
                        
                        processedCount += 1
                    }
                } catch {
                    await MainActor.run {
                        errorCount += 1
                        errors.append("\(plant.name): \(error.localizedDescription)")
                        processedCount += 1
                    }
                }
            }
            
            await MainActor.run {
                progress = 1.0
                isProcessing = false
                showingResults = true
            }
        }
    }
}