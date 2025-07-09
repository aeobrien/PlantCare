import SwiftUI

struct AIPlantAddView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss
    
    @State private var plantName = ""
    @State private var placementPreference: SpacePlacementPreference = .noPreference
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
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Placement Preference")
                        .font(.headline)
                    
                    Picker("Placement", selection: $placementPreference) {
                        ForEach(SpacePlacementPreference.allCases, id: \.self) { preference in
                            Text(preference.rawValue).tag(preference)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
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
                    zones: dataStore.zones,
                    preference: placementPreference,
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
    @State private var selectedZoneID: UUID?
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
                    if !plantData.spaces.isEmpty {
                        HStack {
                            Image(systemName: "sparkles")
                                .foregroundColor(.red)
                            Text("AI Recommendations")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                        
                        ForEach(plantData.spaces.prefix(2).enumerated().map { ($0.offset, $0.element) }, id: \.1) { index, spaceName in
                            let spaceType = index < plantData.spaceTypes.count ? plantData.spaceTypes[index] : "indoor"
                            
                            if spaceType == "indoor" {
                                if let room = dataStore.rooms.first(where: { $0.name == spaceName }) {
                                    Button(action: {
                                        selectedRoomID = room.id
                                        selectedZoneID = nil
                                        if room.windows.count == 1 {
                                            selectedWindowID = room.windows.first?.id
                                        }
                                    }) {
                                        HStack {
                                            Image(systemName: "house")
                                                .foregroundColor(.blue)
                                            Text(room.name)
                                            Text(index == 0 ? "(1st Choice)" : "(2nd Choice)")
                                                .font(.caption)
                                            Spacer()
                                            if selectedRoomID == room.id {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(.green)
                                            }
                                        }
                                    }
                                    .foregroundColor(selectedRoomID == room.id ? .primary : .red)
                                }
                            } else {
                                if let zone = dataStore.zones.first(where: { $0.name == spaceName }) {
                                    Button(action: {
                                        selectedZoneID = zone.id
                                        selectedRoomID = nil
                                        selectedWindowID = nil
                                    }) {
                                        HStack {
                                            Image(systemName: "sun.max")
                                                .foregroundColor(.green)
                                            Text(zone.name)
                                            Text(index == 0 ? "(1st Choice)" : "(2nd Choice)")
                                                .font(.caption)
                                            Spacer()
                                            if selectedZoneID == zone.id {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(.green)
                                            }
                                        }
                                    }
                                    .foregroundColor(selectedZoneID == zone.id ? .primary : .red)
                                }
                            }
                        }
                        
                        Divider()
                    }
                    
                    Picker("Space Type", selection: Binding(
                        get: { selectedRoomID != nil ? 0 : (selectedZoneID != nil ? 1 : 0) },
                        set: { newValue in
                            if newValue == 0 {
                                selectedZoneID = nil
                            } else {
                                selectedRoomID = nil
                                selectedWindowID = nil
                            }
                        }
                    )) {
                        Text("Indoor").tag(0)
                        Text("Outdoor").tag(1)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    
                    if selectedRoomID != nil || (selectedRoomID == nil && selectedZoneID == nil) {
                        Picker("Indoor Space", selection: $selectedRoomID) {
                            Text("None").tag(nil as UUID?)
                            ForEach(dataStore.rooms.sorted(by: { $0.orderIndex < $1.orderIndex })) { room in
                                Text(room.name).tag(room.id as UUID?)
                            }
                        }
                        .onChange(of: selectedRoomID) { newRoomID in
                            if let roomID = newRoomID,
                               let room = dataStore.rooms.first(where: { $0.id == roomID }),
                               room.windows.count == 1,
                               let window = room.windows.first {
                                selectedWindowID = window.id
                            } else if newRoomID == nil {
                                selectedWindowID = nil
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
                    } else {
                        Picker("Outdoor Zone", selection: $selectedZoneID) {
                            Text("None").tag(nil as UUID?)
                            ForEach(dataStore.zones.sorted(by: { $0.orderIndex < $1.orderIndex })) { zone in
                                Text(zone.name).tag(zone.id as UUID?)
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
            assignedZoneID: selectedZoneID,
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