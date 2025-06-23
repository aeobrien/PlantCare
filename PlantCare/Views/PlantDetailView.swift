import SwiftUI

struct PlantDetailView: View {
    @EnvironmentObject var dataStore: DataStore
    @State var plant: Plant
    @State private var isEditing = false
    
    var room: Room? {
        dataStore.roomForPlant(plant)
    }
    
    var window: Window? {
        dataStore.windowForPlant(plant)
    }
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 16) {
                    SectionHeader(title: "Location & Light")
                    
                    VStack(spacing: 12) {
                        InfoRow(
                            icon: "house",
                            label: "Room",
                            value: room?.name ?? "Not assigned",
                            isEmpty: room == nil
                        )
                        
                        if let window = window {
                            InfoRow(
                                icon: "window.ceiling",
                                label: "Window",
                                value: window.direction.rawValue
                            )
                        }
                        
                        InfoRow(
                            icon: lightIcon,
                            label: "Light Type",
                            value: plant.lightType.rawValue
                        )
                        
                        InfoRow(
                            icon: "location.north.line",
                            label: "Preferred Direction",
                            value: plant.preferredLightDirection.rawValue
                        )
                    }
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        SectionHeader(title: "Care Steps")
                        Spacer()
                        Button(action: {
                            isEditing = true
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                        }
                    }
                    
                    if plant.careSteps.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "leaf.circle")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            
                            Text("No care steps configured")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Text("Tap the + button to add care steps")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    } else {
                        VStack(spacing: 8) {
                            ForEach(plant.careSteps) { careStep in
                                CareStepDetailCard(careStep: careStep)
                            }
                        }
                    }
                }
                
                if let humidity = plant.humidityPreference {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "Environment")
                        
                        InfoRow(
                            icon: "humidity",
                            label: "Humidity",
                            value: humidity.rawValue
                        )
                    }
                }
                
                if !plant.generalNotes.isEmpty {
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeader(title: "General Notes")
                        
                        Text(plant.generalNotes)
                            .font(.body)
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .cornerRadius(8)
                    }
                }
                
                if let wateringStep = plant.wateringStep {
                    Button(action: {
                        markWateringStepCompleted()
                    }) {
                        HStack {
                            Image(systemName: "drop.fill")
                            Text("Mark as Watered")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                    .padding(.top)
                }
            }
            .padding()
        }
        .navigationTitle(plant.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: {
                        isEditing = true
                    }) {
                        Label("Edit", systemImage: "pencil")
                    }
                    
                    Button(action: duplicatePlant) {
                        Label("Duplicate", systemImage: "doc.on.doc")
                    }
                } label: {
                    Text("Edit")
                }
            }
        }
        .sheet(isPresented: $isEditing) {
            EditPlantView(plant: $plant)
        }
    }
    
    var lightIcon: String {
        switch plant.lightType {
        case .direct:
            return "sun.max.fill"
        case .indirect:
            return "sun.max"
        case .low:
            return "moon"
        }
    }
    
    func markWateringStepCompleted() {
        if let wateringStep = plant.wateringStep {
            plant.markCareStepCompleted(withId: wateringStep.id)
            dataStore.updatePlant(plant)
        }
    }
    
    func duplicatePlant() {
        var newPlant = plant
        newPlant.id = UUID()
        newPlant.name = "\(plant.name) (Copy)"
        // Reset last completed dates for all care steps
        for i in 0..<newPlant.careSteps.count {
            newPlant.careSteps[i].lastCompletedDate = nil
        }
        dataStore.addPlant(newPlant)
    }
}

struct SectionHeader: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.headline)
            .foregroundColor(.primary)
    }
}

struct InfoRow: View {
    let icon: String
    let label: String
    let value: String
    var isEmpty: Bool = false
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(isEmpty ? .secondary : .blue)
                .frame(width: 20)
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .foregroundColor(isEmpty ? .secondary : .primary)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
}

struct CareStepDetailCard: View {
    let careStep: CareStep
    
    var statusText: String {
        if careStep.isOverdue {
            if let daysSince = careStep.daysSinceLastCompleted {
                return "Overdue by \(daysSince - careStep.frequencyDays) days"
            }
            return "Overdue"
        } else if let daysUntil = careStep.daysUntilDue {
            if daysUntil == 0 {
                return "Due today"
            } else if daysUntil == 1 {
                return "Due tomorrow"
            } else {
                return "Due in \(daysUntil) days"
            }
        }
        return "Due today"
    }
    
    var statusColor: Color {
        if careStep.isOverdue {
            return .red
        } else if let daysUntil = careStep.daysUntilDue, daysUntil == 0 {
            return .orange
        }
        return .secondary
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: careStep.type.systemImageName)
                    .foregroundColor(.blue)
                    .frame(width: 20)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(careStep.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Every \(careStep.frequencyDays) days")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 2) {
                    Text(statusText)
                        .font(.caption)
                        .foregroundColor(statusColor)
                        .fontWeight(.medium)
                    
                    if let lastCompleted = careStep.lastCompletedDate {
                        Text("Last: \(lastCompleted.formatted(date: .abbreviated, time: .omitted))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Never completed")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Text(careStep.instructions)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.horizontal, 24)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(careStep.isOverdue ? Color.red.opacity(0.1) : Color(.systemGray6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(careStep.isOverdue ? Color.red : Color.clear, lineWidth: 1)
        )
    }
}

struct EditPlantView: View {
    @Binding var plant: Plant
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss
    
    @State private var plantName: String = ""
    @State private var selectedRoomID: UUID?
    @State private var selectedWindowID: UUID?
    @State private var preferredLightDirection: Direction = .east
    @State private var lightType: LightType = .indirect
    @State private var generalNotes: String = ""
    @State private var humidityPreference: HumidityPreference = .medium
    @State private var careSteps: [CareStep] = []
    @State private var showingAddCareStep = false
    
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
                
                Section(header: Text("Location")) {
                    Picker("Room", selection: $selectedRoomID) {
                        Text("None").tag(nil as UUID?)
                        ForEach(dataStore.rooms.sorted(by: { $0.orderIndex < $1.orderIndex })) { room in
                            Text(room.name).tag(room.id as UUID?)
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
                
                Section(header: 
                    HStack {
                        Text("Care Steps")
                        Spacer()
                        Button(action: { showingAddCareStep = true }) {
                            Image(systemName: "plus")
                        }
                    }
                ) {
                    if careSteps.isEmpty {
                        Text("No care steps configured")
                            .foregroundColor(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(careSteps) { careStep in
                            CareStepEditRow(
                                careStep: careStep,
                                onEdit: { editedStep in
                                    if let index = careSteps.firstIndex(where: { $0.id == editedStep.id }) {
                                        careSteps[index] = editedStep
                                    }
                                },
                                onDelete: {
                                    careSteps.removeAll { $0.id == careStep.id }
                                }
                            )
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
                
                Section(header: Text("General Notes")) {
                    TextEditor(text: $generalNotes)
                        .frame(height: 80)
                }
            }
            .navigationTitle("Edit Plant")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveChanges()
                    }
                }
            }
            .sheet(isPresented: $showingAddCareStep) {
                AddCareStepView { newStep in
                    careSteps.append(newStep)
                }
            }
            .onAppear {
                plantName = plant.name
                selectedRoomID = plant.assignedRoomID
                selectedWindowID = plant.assignedWindowID
                preferredLightDirection = plant.preferredLightDirection
                lightType = plant.lightType
                generalNotes = plant.generalNotes
                humidityPreference = plant.humidityPreference ?? .medium
                careSteps = plant.careSteps
            }
        }
    }
    
    func saveChanges() {
        plant.name = plantName
        plant.assignedRoomID = selectedRoomID
        plant.assignedWindowID = selectedWindowID
        plant.preferredLightDirection = preferredLightDirection
        plant.lightType = lightType
        plant.generalNotes = generalNotes
        plant.humidityPreference = humidityPreference
        plant.careSteps = careSteps
        
        dataStore.updatePlant(plant)
        dismiss()
    }
}

struct CareStepEditRow: View {
    let careStep: CareStep
    let onEdit: (CareStep) -> Void
    let onDelete: () -> Void
    @State private var showingEditSheet = false
    
    var body: some View {
        HStack {
            Image(systemName: careStep.type.systemImageName)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(careStep.displayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text("Every \(careStep.frequencyDays) days")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("Edit") {
                showingEditSheet = true
            }
            .font(.caption)
        }
        .contentShape(Rectangle())
        .sheet(isPresented: $showingEditSheet) {
            EditCareStepView(careStep: careStep) { editedStep in
                onEdit(editedStep)
            }
        }
        .swipeActions(edge: .trailing) {
            Button("Delete", role: .destructive) {
                onDelete()
            }
        }
    }
}

struct AddCareStepView: View {
    let onAdd: (CareStep) -> Void
    @Environment(\.dismiss) var dismiss
    
    @State private var selectedType: CareStepType = .watering
    @State private var customName = ""
    @State private var instructions = ""
    @State private var frequencyDays = 7
    
    var displayName: String {
        if selectedType == .custom && !customName.isEmpty {
            return customName
        }
        return selectedType.rawValue
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Care Step Type")) {
                    Picker("Type", selection: $selectedType) {
                        ForEach(CareStepType.allCases, id: \.self) { type in
                            HStack {
                                Image(systemName: type.systemImageName)
                                Text(type.rawValue)
                            }
                            .tag(type)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    if selectedType == .custom {
                        TextField("Custom name", text: $customName)
                    }
                }
                
                Section(header: Text("Instructions")) {
                    TextEditor(text: $instructions)
                        .frame(height: 80)
                }
                
                Section(header: Text("Frequency")) {
                    HStack {
                        Text("Every")
                        Picker("Days", selection: $frequencyDays) {
                            ForEach([1, 2, 3, 5, 7, 10, 14, 21, 30], id: \.self) { days in
                                Text("\(days)").tag(days)
                            }
                        }
                        .pickerStyle(WheelPickerStyle())
                        .frame(width: 80)
                        Text("days")
                    }
                }
            }
            .navigationTitle("Add Care Step")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        let careStep = CareStep(
                            type: selectedType,
                            customName: selectedType == .custom ? customName : nil,
                            instructions: instructions,
                            frequencyDays: frequencyDays
                        )
                        onAdd(careStep)
                        dismiss()
                    }
                    .disabled(instructions.isEmpty || (selectedType == .custom && customName.isEmpty))
                }
            }
        }
    }
}

struct EditCareStepView: View {
    @State private var careStep: CareStep
    let onSave: (CareStep) -> Void
    @Environment(\.dismiss) var dismiss
    
    init(careStep: CareStep, onSave: @escaping (CareStep) -> Void) {
        self._careStep = State(initialValue: careStep)
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Care Step Type")) {
                    Picker("Type", selection: $careStep.type) {
                        ForEach(CareStepType.allCases, id: \.self) { type in
                            HStack {
                                Image(systemName: type.systemImageName)
                                Text(type.rawValue)
                            }
                            .tag(type)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    
                    if careStep.type == .custom {
                        TextField("Custom name", text: Binding(
                            get: { careStep.customName ?? "" },
                            set: { careStep.customName = $0 }
                        ))
                    }
                }
                
                Section(header: Text("Instructions")) {
                    TextEditor(text: $careStep.instructions)
                        .frame(height: 80)
                }
                
                Section(header: Text("Frequency")) {
                    HStack {
                        Text("Every")
                        Picker("Days", selection: $careStep.frequencyDays) {
                            ForEach([1, 2, 3, 5, 7, 10, 14, 21, 30], id: \.self) { days in
                                Text("\(days)").tag(days)
                            }
                        }
                        .pickerStyle(WheelPickerStyle())
                        .frame(width: 80)
                        Text("days")
                    }
                }
                
                Section(header: Text("Status")) {
                    Toggle("Enabled", isOn: $careStep.isEnabled)
                    
                    if let lastCompleted = careStep.lastCompletedDate {
                        HStack {
                            Text("Last Completed")
                            Spacer()
                            Text(lastCompleted.formatted(date: .abbreviated, time: .omitted))
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Edit Care Step")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        onSave(careStep)
                        dismiss()
                    }
                    .disabled(careStep.instructions.isEmpty || (careStep.type == .custom && (careStep.customName?.isEmpty ?? true)))
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        PlantDetailView(plant: DataStore.shared.plants.first!)
            .environmentObject(DataStore.shared)
    }
}