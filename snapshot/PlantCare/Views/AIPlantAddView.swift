import SwiftUI
import PhotosUI
import UIKit

struct AIPlantAddView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss
    var onPlantCreated: ((UUID) -> Void)? = nil
    
    @State private var plantName = ""
    @State private var placementPreference: SpacePlacementPreference = .noPreference
    @State private var isLoading = false
    @State private var showingAddPlantView = false
    @State private var generatedPlantData: AIPlantResponse?
    @State private var errorMessage = ""
    @State private var showingError = false
    @State private var showingImagePicker = false
    @State private var capturedImage: UIImage?
    @State private var identifiedPlantName = ""
    
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
                    HStack {
                        Text("Plant Name")
                            .font(.headline)
                        Spacer()
                        Button(action: {
                            showingImagePicker = true
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "camera.fill")
                                Text("Identify with Photo")
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                        }
                    }
                    
                    TextField("e.g., Monstera, Fiddle Leaf Fig, Snake Plant", text: $plantName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.words)
                    
                    if let image = capturedImage {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 100)
                            .cornerRadius(8)
                            .padding(.top, 4)
                    }
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
                    AIGeneratedAddPlantView(plantData: plantData) { plantID in
                        // First dismiss the AI add view
                        dismiss()
                        // Then call the original completion handler if provided
                        if let onPlantCreated = onPlantCreated {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onPlantCreated(plantID)
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(image: $capturedImage, sourceType: .camera)
                    .onDisappear {
                        if let image = capturedImage {
                            identifyPlant(from: image)
                        }
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
    
    func identifyPlant(from image: UIImage) {
        isLoading = true
        errorMessage = ""
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            errorMessage = "Failed to process image"
            showingError = true
            isLoading = false
            return
        }
        
        Task {
            do {
                let identifiedName = try await OpenAIService.shared.identifyPlant(
                    from: imageData,
                    apiKey: dataStore.settings.openAIAPIKey
                )
                
                await MainActor.run {
                    self.plantName = identifiedName
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
    var onPlantCreated: ((UUID) -> Void)? = nil
    
    let plantData: AIPlantResponse
    
    @State private var plantName: String
    @State private var latinName: String
    @State private var visualDescription: String
    @State private var selectedRoomID: UUID?
    @State private var selectedZoneID: UUID?
    @State private var selectedWindowID: UUID?
    @State private var preferredLightDirection: Direction
    @State private var lightType: LightType
    @State private var generalNotes: String
    @State private var humidityPreference: HumidityPreference
    @State private var careSteps: [CareStep] = []
    
    init(plantData: AIPlantResponse, onPlantCreated: ((UUID) -> Void)? = nil) {
        self.plantData = plantData
        self.onPlantCreated = onPlantCreated
        self._plantName = State(initialValue: plantData.name)
        self._latinName = State(initialValue: plantData.latinName ?? "")
        self._visualDescription = State(initialValue: plantData.visualDescription ?? "")
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
                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Common Name")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("Common Name", text: $plantName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Latin Name")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("Latin Name (optional)", text: $latinName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Visual Description")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            TextField("Visual Description (optional)", text: $visualDescription)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Light Type")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("Light Type", selection: $lightType) {
                            ForEach(LightType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Preferred Light Direction")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("Preferred Light Direction", selection: $preferredLightDirection) {
                            ForEach(Direction.allCases, id: \.self) { direction in
                                Text(direction.rawValue).tag(direction)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
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
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Humidity Preference")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Picker("Humidity Preference", selection: $humidityPreference) {
                            ForEach(HumidityPreference.allCases, id: \.self) { pref in
                                Text(pref.rawValue).tag(pref)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                }
                
                Section(header: Text("Care Steps")) {
                    ForEach(careSteps) { step in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: step.type.systemImageName)
                                    .foregroundColor(.accentColor)
                                Text(step.displayName)
                                    .font(.headline)
                                Spacer()
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("Frequency")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    Text("Every \(step.frequencyDays) days")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                }
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Instructions")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(step.instructions)
                                    .font(.caption)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                }
                
                Section(header: Text("General Notes")) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("AI-Generated Care Notes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        TextEditor(text: $generalNotes)
                            .frame(height: 80)
                    }
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
        let newPlantID = UUID()
        var newPlant = Plant(
            id: newPlantID,
            name: plantName,
            latinName: latinName.isEmpty ? nil : latinName,
            visualDescription: visualDescription.isEmpty ? nil : visualDescription,
            assignedRoomID: selectedRoomID,
            assignedZoneID: selectedZoneID,
            assignedWindowID: selectedWindowID,
            preferredLightDirection: preferredLightDirection,
            lightType: lightType,
            generalNotes: generalNotes,
            careSteps: [],
            humidityPreference: humidityPreference
        )
        
        // Add care steps
        for step in careSteps {
            newPlant.addCareStep(step)
        }
        
        dataStore.addPlant(newPlant)
        
        // Dismiss this view
        dismiss()
        
        // Call the completion handler if provided after a delay to ensure proper dismissal
        if let onPlantCreated = onPlantCreated {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                onPlantCreated(newPlantID)
            }
        }
    }
}

#Preview {
    AIPlantAddView()
        .environmentObject(DataStore.shared)
}