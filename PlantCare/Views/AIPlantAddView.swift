import SwiftUI

struct AIPlantAddView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss
    
    @State private var plantName = ""
    @State private var isLoading = false
    @State private var showingAddPlantView = false
    @State private var generatedPlantData: AIPlantResponse?
    @State private var errorMessage = ""
    @State private var showingError = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Add Plant via AI")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Enter the name of your plant and I'll provide personalized care recommendations based on your home's layout.")
                        .font(.body)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.top, 20)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Plant Name")
                        .font(.headline)
                    
                    TextField("e.g., Monstera, Fiddle Leaf Fig, Snake Plant", text: $plantName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.words)
                }
                .padding(.horizontal)
                
                if dataStore.settings.openAIAPIKey.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.largeTitle)
                            .foregroundColor(.orange)
                        
                        Text("API Key Required")
                            .font(.headline)
                        
                        Text("Please add your OpenAI API key in Settings to use AI recommendations.")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                        
                        Button("Go to Settings") {
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }
                
                Spacer()
                
                if !dataStore.settings.openAIAPIKey.isEmpty {
                    Button(action: generateAIRecommendation) {
                        if isLoading {
                            HStack {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle())
                                    .scaleEffect(0.8)
                                Text("Getting recommendations...")
                                    .padding(.leading, 8)
                            }
                        } else {
                            HStack {
                                Image(systemName: "sparkles")
                                Text("Get AI Recommendations")
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(plantName.isEmpty || isLoading)
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
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
            .sheet(isPresented: $showingAddPlantView) {
                if let plantData = generatedPlantData {
                    AIGeneratedAddPlantView(plantData: plantData)
                }
            }
        }
    }
    
    func generateAIRecommendation() {
        isLoading = true
        errorMessage = ""
        
        Task {
            do {
                let response = try await OpenAIService.shared.generatePlantRecommendation(
                    plantName: plantName,
                    rooms: dataStore.rooms,
                    apiKey: dataStore.settings.openAIAPIKey
                )
                
                await MainActor.run {
                    self.generatedPlantData = response
                    self.showingAddPlantView = true
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
}

struct AIGeneratedAddPlantView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss
    
    let plantData: AIPlantResponse
    
    @State private var plantName: String
    @State private var selectedRoomID: UUID?
    @State private var selectedWindowID: UUID?
    @State private var preferredLightDirection: Direction
    @State private var lightType: LightType
    @State private var generalNotes: String
    @State private var humidityPreference: HumidityPreference
    @State private var careSteps: [CareStep] = []
    
    init(plantData: AIPlantResponse) {
        self.plantData = plantData
        self._plantName = State(initialValue: plantData.name)
        self._preferredLightDirection = State(initialValue: plantData.preferredLightDirection)
        self._lightType = State(initialValue: plantData.lightType)
        self._generalNotes = State(initialValue: plantData.generalNotes)
        self._humidityPreference = State(initialValue: plantData.humidityPreference ?? .medium)
        
        // Initialize care steps
        var steps: [CareStep] = []
        
        // Add watering step
        steps.append(CareStep(
            type: .watering,
            instructions: plantData.wateringInstructions,
            frequencyDays: plantData.wateringFrequencyDays
        ))
        
        // Add other care steps if provided
        if let mistingDays = plantData.mistingFrequencyDays {
            steps.append(CareStep(
                type: .misting,
                instructions: plantData.mistingInstructions ?? "Mist leaves regularly",
                frequencyDays: mistingDays
            ))
        }
        
        if let dustingDays = plantData.dustingFrequencyDays {
            steps.append(CareStep(
                type: .dusting,
                instructions: plantData.dustingInstructions ?? "Dust leaves gently",
                frequencyDays: dustingDays
            ))
        }
        
        if let rotationDays = plantData.rotationFrequencyDays {
            steps.append(CareStep(
                type: .rotation,
                instructions: plantData.rotationInstructions ?? "Rotate plant for even growth",
                frequencyDays: rotationDays
            ))
        }
        
        self._careSteps = State(initialValue: steps)
    }
    
    var selectedRoom: Room? {
        guard let roomID = selectedRoomID else { return nil }
        return dataStore.rooms.first { $0.id == roomID }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Plant Information")) {
                    TextField("Plant Name", text: $plantName)
                    
                    Picker("Light Type", selection: $lightType) {
                        ForEach(LightType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    
                    Picker("Preferred Light Direction", selection: $preferredLightDirection) {
                        ForEach(Direction.allCases, id: \.self) { direction in
                            Text(direction.rawValue).tag(direction)
                        }
                    }
                }
                
                Section(header: Text("AI Recommended Location")) {
                    VStack(alignment: .leading, spacing: 8) {
                        if let firstChoice = plantData.recommendedRooms.first,
                           let room = dataStore.rooms.first(where: { $0.name == firstChoice }) {
                            
                            HStack {
                                Image(systemName: "sparkles")
                                    .foregroundColor(.red)
                                Text("AI Recommendation")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                            
                            Picker("Room", selection: $selectedRoomID) {
                                Text("None").tag(nil as UUID?)
                                
                                // Show recommended rooms first in red
                                ForEach(plantData.recommendedRooms.prefix(2).enumerated().map { ($0.offset, $0.element) }, id: \.1) { index, roomName in
                                    if let room = dataStore.rooms.first(where: { $0.name == roomName }) {
                                        HStack {
                                            Text(room.name)
                                                .foregroundColor(.red)
                                            Text(index == 0 ? "(1st Choice)" : "(2nd Choice)")
                                                .font(.caption)
                                                .foregroundColor(.red)
                                        }
                                        .tag(room.id as UUID?)
                                    }
                                }
                                
                                // Show other rooms
                                ForEach(dataStore.rooms.sorted(by: { $0.orderIndex < $1.orderIndex })) { room in
                                    if !plantData.recommendedRooms.prefix(2).contains(room.name) {
                                        Text(room.name).tag(room.id as UUID?)
                                    }
                                }
                            }
                            .onAppear {
                                // Set the first recommended room as default
                                if selectedRoomID == nil,
                                   let firstRoom = dataStore.rooms.first(where: { $0.name == firstChoice }) {
                                    selectedRoomID = firstRoom.id
                                }
                            }
                            .onChange(of: selectedRoomID) { newRoomID in
                                // Auto-select window if room has only one
                                if let roomID = newRoomID,
                                   let room = dataStore.rooms.first(where: { $0.id == roomID }),
                                   room.windows.count == 1,
                                   let window = room.windows.first {
                                    selectedWindowID = window.id
                                } else if newRoomID == nil {
                                    selectedWindowID = nil
                                }
                            }
                        } else {
                            Picker("Room", selection: $selectedRoomID) {
                                Text("None").tag(nil as UUID?)
                                ForEach(dataStore.rooms.sorted(by: { $0.orderIndex < $1.orderIndex })) { room in
                                    Text(room.name).tag(room.id as UUID?)
                                }
                            }
                            .onChange(of: selectedRoomID) { newRoomID in
                                // Auto-select window if room has only one
                                if let roomID = newRoomID,
                                   let room = dataStore.rooms.first(where: { $0.id == roomID }),
                                   room.windows.count == 1,
                                   let window = room.windows.first {
                                    selectedWindowID = window.id
                                } else if newRoomID == nil {
                                    selectedWindowID = nil
                                }
                            }
                        }
                        
                        if let room = selectedRoom, !room.windows.isEmpty {
                            Picker("Window", selection: $selectedWindowID) {
                                Text("None").tag(nil as UUID?)
                                ForEach(room.windows) { window in
                                    Text(window.direction.rawValue).tag(window.id as UUID?)
                                }
                            }
                        }
                    }
                }
                
                Section(header: Text("Environment")) {
                    Picker("Humidity Preference", selection: $humidityPreference) {
                        ForEach(HumidityPreference.allCases, id: \.self) { pref in
                            Text(pref.rawValue).tag(pref)
                        }
                    }
                }
                
                Section(header: Text("Care Steps")) {
                    ForEach(careSteps) { step in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Image(systemName: step.type.systemImageName)
                                    .foregroundColor(.accentColor)
                                Text(step.displayName)
                                    .font(.headline)
                                Spacer()
                                Text("Every \(step.frequencyDays) days")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Text(step.instructions)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                Section(header: Text("General Notes")) {
                    TextEditor(text: $generalNotes)
                        .frame(height: 80)
                }
            }
            .navigationTitle("Add Plant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        savePlant()
                    }
                    .disabled(plantName.isEmpty)
                }
            }
        }
    }
    
    func savePlant() {
        var newPlant = Plant(
            name: plantName,
            assignedRoomID: selectedRoomID,
            assignedWindowID: selectedWindowID,
            preferredLightDirection: preferredLightDirection,
            lightType: lightType,
            generalNotes: generalNotes,
            humidityPreference: humidityPreference
        )
        
        // Add care steps
        for step in careSteps {
            newPlant.addCareStep(step)
        }
        
        dataStore.addPlant(newPlant)
        dismiss()
    }
}

#Preview {
    AIPlantAddView()
        .environmentObject(DataStore.shared)
}