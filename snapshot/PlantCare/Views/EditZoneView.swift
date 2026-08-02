import SwiftUI

struct EditZoneView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss
    
    let zone: Zone
    
    @State private var zoneName: String
    @State private var selectedAspect: ZoneAspect
    @State private var selectedSunPeriod: SunPeriod
    @State private var selectedWindExposure: WindExposure
    @State private var selectedSunHours: SunHours?
    @State private var provideSunHours: Bool
    
    init(zone: Zone) {
        self.zone = zone
        _zoneName = State(initialValue: zone.name)
        _selectedAspect = State(initialValue: zone.aspect)
        _selectedSunPeriod = State(initialValue: zone.sunPeriod)
        _selectedWindExposure = State(initialValue: zone.wind)
        _selectedSunHours = State(initialValue: zone.sunHours)
        _provideSunHours = State(initialValue: zone.sunHours != nil)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Zone Name") {
                    TextField("Zone name", text: $zoneName)
                }
                
                Section("Location Details") {
                    Picker("Aspect", selection: $selectedAspect) {
                        ForEach(ZoneAspect.allCases, id: \.self) { aspect in
                            Text(aspect.rawValue).tag(aspect)
                        }
                    }
                    
                    Picker("Sun Period", selection: $selectedSunPeriod) {
                        ForEach(SunPeriod.allCases, id: \.self) { period in
                            Text(period.rawValue).tag(period)
                        }
                    }
                    
                    Picker("Wind Exposure", selection: $selectedWindExposure) {
                        ForEach(WindExposure.allCases, id: \.self) { exposure in
                            Text(exposure.rawValue).tag(exposure)
                        }
                    }
                }
                
                Section {
                    Toggle("Specify sun hours", isOn: $provideSunHours)
                    
                    if provideSunHours {
                        Picker("Sun Hours", selection: Binding(
                            get: { selectedSunHours ?? zone.inferredSunHours },
                            set: { selectedSunHours = $0 }
                        )) {
                            ForEach(SunHours.allCases, id: \.self) { hours in
                                Text(hours.rawValue).tag(hours)
                            }
                        }
                    }
                } header: {
                    Text("Sun Hours")
                } footer: {
                    if !provideSunHours {
                        Text("If not specified, sun hours will be estimated based on aspect and sun period.")
                    }
                }
            }
            .navigationTitle("Edit Zone")
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
                    .fontWeight(.semibold)
                    .disabled(zoneName.isEmpty)
                }
            }
        }
    }
    
    private func saveChanges() {
        var updatedZone = zone
        updatedZone.name = zoneName
        updatedZone.aspect = selectedAspect
        updatedZone.sunPeriod = selectedSunPeriod
        updatedZone.wind = selectedWindExposure
        updatedZone.sunHours = provideSunHours ? selectedSunHours : nil
        
        dataStore.updateZone(updatedZone)
        dismiss()
    }
}

#Preview {
    EditZoneView(zone: Zone(
        name: "Front Patio",
        aspect: .southWall,
        sunPeriod: .all,
        wind: .sheltered,
        orderIndex: 0
    ))
    .environmentObject(DataStore.shared)
}