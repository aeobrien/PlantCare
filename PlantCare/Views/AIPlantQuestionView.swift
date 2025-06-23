import SwiftUI

struct AIPlantQuestionView: View {
    let plant: Plant
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss
    
    @State private var question = ""
    @State private var isLoading = false
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var aiResponse: AIPlantQuestionResponse?
    @State private var showingReview = false
    
    @FocusState private var isQuestionFocused: Bool
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        PlantInfoCard(plant: plant, room: dataStore.roomForPlant(plant))
                        
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Ask about \(plant.name)")
                                .font(.headline)
                            
                            TextEditor(text: $question)
                                .frame(minHeight: 100)
                                .padding(8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                                .focused($isQuestionFocused)
                            
                            Text("Examples: Is this plant getting enough light? Should I adjust the watering schedule? Is the room humidity appropriate?")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        if let response = aiResponse {
                            VStack(alignment: .leading, spacing: 16) {
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Image(systemName: "bubble.left.fill")
                                            .foregroundColor(.blue)
                                        Text("AI Response")
                                            .font(.headline)
                                    }
                                    
                                    Text(response.answer)
                                        .font(.body)
                                        .padding()
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                }
                                
                                if response.suggestedChanges != nil {
                                    Button(action: {
                                        showingReview = true
                                    }) {
                                        HStack {
                                            Image(systemName: "wand.and.stars")
                                            Text("Review Suggested Changes")
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(Color.blue)
                                        .foregroundColor(.white)
                                        .cornerRadius(8)
                                    }
                                }
                            }
                        }
                    }
                    .padding()
                }
                
                if !isLoading && aiResponse == nil {
                    VStack {
                        Divider()
                        
                        Button(action: askQuestion) {
                            HStack {
                                Image(systemName: "paperplane.fill")
                                Text("Ask AI")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(question.isEmpty ? Color(.systemGray5) : Color.blue)
                            .foregroundColor(question.isEmpty ? Color(.systemGray) : .white)
                            .cornerRadius(8)
                        }
                        .disabled(question.isEmpty || isLoading)
                        .padding()
                    }
                    .background(Color(.systemBackground))
                }
            }
            .navigationTitle("Ask AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                if aiResponse != nil {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("New Question") {
                            resetForNewQuestion()
                        }
                    }
                }
            }
            .overlay {
                if isLoading {
                    LoadingView()
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showingReview) {
                if let response = aiResponse, let changes = response.suggestedChanges {
                    PlantChangeReviewView(
                        plant: plant,
                        suggestedChanges: changes,
                        onApprove: { updatedPlant in
                            dataStore.updatePlant(updatedPlant)
                            dismiss()
                        }
                    )
                }
            }
            .onAppear {
                isQuestionFocused = true
            }
        }
    }
    
    func askQuestion() {
        isLoading = true
        isQuestionFocused = false
        
        Task {
            do {
                let apiKey = dataStore.settings.openAIAPIKey
                guard !apiKey.isEmpty else {
                    throw APIError.openAIError("OpenAI API key not configured")
                }
                
                let response = try await OpenAIService.shared.askPlantQuestion(
                    question: question,
                    plant: plant,
                    rooms: dataStore.rooms,
                    apiKey: apiKey
                )
                
                await MainActor.run {
                    self.aiResponse = response
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.showingError = true
                    self.isLoading = false
                }
            }
        }
    }
    
    func resetForNewQuestion() {
        question = ""
        aiResponse = nil
        isQuestionFocused = true
    }
}

struct PlantInfoCard: View {
    let plant: Plant
    let room: Room?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plant.name)
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    if let room = room {
                        Text("Currently in \(room.name)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "leaf.fill")
                    .font(.title2)
                    .foregroundColor(.green)
            }
            
            HStack(spacing: 16) {
                Label(plant.lightType.rawValue, systemImage: plant.lightIcon)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let humidity = plant.humidityPreference {
                    Label(humidity.rawValue + " humidity", systemImage: "humidity")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct LoadingView: View {
    var body: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                Text("Asking AI...")
                    .font(.headline)
            }
            .padding(32)
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(radius: 10)
        }
    }
}

extension Plant {
    var lightIcon: String {
        switch lightType {
        case .direct:
            return "sun.max.fill"
        case .indirect:
            return "sun.max"
        case .low:
            return "moon"
        }
    }
}

#Preview {
    AIPlantQuestionView(plant: DataStore.shared.plants.first!)
        .environmentObject(DataStore.shared)
}