import SwiftUI

struct AddZoneView: View {
    @EnvironmentObject var dataStore: DataStore
    @Environment(\.dismiss) var dismiss
    
    @State private var zoneName = ""
    @State private var selectedAspect: ZoneAspect = .open
    @State private var selectedSunPeriod: SunPeriod = .all
    @State private var selectedWindExposure: WindExposure = .sheltered
    @State private var selectedSunHours: SunHours?
    @State private var provideSunHours = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Zone Name") {
                    TextField("e.g., Front-door pots, Patio corner", text: $zoneName)
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
                            get: { selectedSunHours ?? .twoToFour },
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
            .navigationTitle("New Outdoor Zone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveZone()
                    }
                    .fontWeight(.semibold)
                    .disabled(zoneName.isEmpty)
                }
            }
        }
    }
    
    private func saveZone() {
        let newZone = Zone(
            name: zoneName,
            aspect: selectedAspect,
            sunPeriod: selectedSunPeriod,
            wind: selectedWindExposure,
            sunHours: provideSunHours ? selectedSunHours : nil,
            orderIndex: dataStore.zones.count
        )
        
        dataStore.addZone(newZone)
        dismiss()
    }
}

#Preview {
    AddZoneView()
        .environmentObject(DataStore.shared)
}