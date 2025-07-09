import Foundation
import Combine

class DataStore: ObservableObject {
    static let shared = DataStore()
    
    @Published var rooms: [Room] = []
    @Published var zones: [Zone] = []
    @Published var plants: [Plant] = []
    @Published var currentCareSession: CareSession?
    @Published var settings: AppSettings = AppSettings()
    
    private let roomsKey = "savedRooms"
    private let zonesKey = "savedZones"
    private let plantsKey = "savedPlants"
    private let settingsKey = "appSettings"
    
    init() {
        loadData()
    }
    
    private func loadData() {
        if let roomsData = UserDefaults.standard.data(forKey: roomsKey),
           let decodedRooms = try? JSONDecoder().decode([Room].self, from: roomsData) {
            self.rooms = decodedRooms
        } else {
            loadDefaultRooms()
        }
        
        if let zonesData = UserDefaults.standard.data(forKey: zonesKey),
           let decodedZones = try? JSONDecoder().decode([Zone].self, from: zonesData) {
            self.zones = decodedZones
        }
        
        if let plantsData = UserDefaults.standard.data(forKey: plantsKey) {
            // Try to decode with new format first
            if let decodedPlants = try? JSONDecoder().decode([Plant].self, from: plantsData) {
                self.plants = decodedPlants
                
                // Check if migration is needed (plants with empty careSteps but old watering data)
                var needsMigration = false
                for plant in plants {
                    if plant.careSteps.isEmpty && hasLegacyWateringData(plant) {
                        needsMigration = true
                        break
                    }
                }
                
                if needsMigration {
                    migrateLegacyPlantData()
                }
            } else {
                // If decoding fails, try legacy format migration
                migrateLegacyPlantDataFromOldFormat(data: plantsData)
            }
        } else {
            loadDefaultPlants()
        }
        
        if let settingsData = UserDefaults.standard.data(forKey: settingsKey),
           let decodedSettings = try? JSONDecoder().decode(AppSettings.self, from: settingsData) {
            self.settings = decodedSettings
        }
    }
    
    private func hasLegacyWateringData(_ plant: Plant) -> Bool {
        // This is a placeholder for checking if a plant has legacy data
        // Since we can't directly check for removed properties, we'll use a heuristic:
        // If a plant has no care steps but exists, it likely needs migration
        return plant.careSteps.isEmpty
    }
    
    private func migrateLegacyPlantData() {
        print("Migrating legacy plant data to new care step format...")
        
        for i in 0..<plants.count {
            var plant = plants[i]
            
            // Only migrate if the plant has no care steps
            if plant.careSteps.isEmpty {
                // Create a default watering care step
                let wateringStep = CareStep(
                    type: .watering,
                    instructions: "Water when needed", // Default instruction
                    frequencyDays: 7 // Default frequency
                )
                
                plant.addCareStep(wateringStep)
                plants[i] = plant
            }
        }
        
        // Save the migrated data
        saveData()
        print("Legacy plant data migration completed.")
    }
    
    private func migrateLegacyPlantDataFromOldFormat(data: Data) {
        print("Attempting to migrate from very old plant format...")
        
        // Since we can't decode the old format directly with the new struct,
        // we'll create new default plants with basic watering care steps
        loadDefaultPlants()
        
        // Note: In a real app, you might want to preserve some data using JSONSerialization
        // to extract individual fields, but for this case we'll start fresh
        print("Created default plants with new care step format.")
    }
    
    func saveData() {
        if let encodedRooms = try? JSONEncoder().encode(rooms) {
            UserDefaults.standard.set(encodedRooms, forKey: roomsKey)
        }
        
        if let encodedZones = try? JSONEncoder().encode(zones) {
            UserDefaults.standard.set(encodedZones, forKey: zonesKey)
        }
        
        if let encodedPlants = try? JSONEncoder().encode(plants) {
            UserDefaults.standard.set(encodedPlants, forKey: plantsKey)
        }
        
        if let encodedSettings = try? JSONEncoder().encode(settings) {
            UserDefaults.standard.set(encodedSettings, forKey: settingsKey)
        }
    }
    
    private func loadDefaultRooms() {
        let defaultRooms = [
            Room(name: "Kitchen", windows: [Window(direction: .northeast)], orderIndex: 0),
            Room(name: "Living Room", windows: [Window(direction: .southwest)], orderIndex: 1),
            Room(name: "Studio", windows: [Window(direction: .southwest)], orderIndex: 2),
            Room(name: "Spare Bedroom", windows: [Window(direction: .southeast), Window(direction: .southwest)], orderIndex: 3),
            Room(name: "Master Bedroom", windows: [Window(direction: .southwest), Window(direction: .northeast)], orderIndex: 4),
            Room(name: "Box Room", windows: [Window(direction: .northeast)], orderIndex: 5),
            Room(name: "Bathroom", windows: [Window(direction: .northeast)], orderIndex: 6)
        ]
        self.rooms = defaultRooms
    }
    
    private func loadDefaultPlants() {
        guard !rooms.isEmpty else { return }
        
        let kitchen = rooms.first { $0.name == "Kitchen" }!
        let livingRoom = rooms.first { $0.name == "Living Room" }!
        let studio = rooms.first { $0.name == "Studio" }!
        let spareBedroom = rooms.first { $0.name == "Spare Bedroom" }!
        let masterBedroom = rooms.first { $0.name == "Master Bedroom" }!
        let boxRoom = rooms.first { $0.name == "Box Room" }!
        let bathroom = rooms.first { $0.name == "Bathroom" }!
        
        var snakePlant = Plant(
            name: "Snake Plant",
            assignedRoomID: livingRoom.id,
            assignedWindowID: livingRoom.windows.first?.id,
            preferredLightDirection: .east,
            lightType: .indirect,
            generalNotes: "Very tolerant of neglect. Can handle low light but prefers bright indirect light",
            humidityPreference: .low
        )
        snakePlant.addCareStep(CareStep(
            type: .watering,
            instructions: "Water every 2-3 weeks, allowing soil to dry out between waterings",
            frequencyDays: 14
        ))
        
        let defaultPlants = [
            snakePlant,
            {
                var pothos = Plant(
                    name: "Pothos",
                    assignedRoomID: kitchen.id,
                    assignedWindowID: kitchen.windows.first?.id,
                    preferredLightDirection: .northeast,
                    lightType: .indirect,
                    generalNotes: "Fast growing, easy care. Trim to control size. Can propagate easily in water",
                    humidityPreference: .medium
                )
                pothos.addCareStep(CareStep(
                    type: .watering,
                    instructions: "Water when top inch of soil is dry, typically once a week",
                    frequencyDays: 7
                ))
                return pothos
            }(),
            {
                var monstera = Plant(
                    name: "Monstera Deliciosa",
                    assignedRoomID: livingRoom.id,
                    assignedWindowID: livingRoom.windows.first?.id,
                    preferredLightDirection: .east,
                    lightType: .indirect,
                    generalNotes: "Needs support as it grows. Benefits from occasional misting",
                    humidityPreference: .high
                )
                monstera.addCareStep(CareStep(
                    type: .watering,
                    instructions: "Water when top 2 inches of soil are dry",
                    frequencyDays: 10
                ))
                monstera.addCareStep(CareStep(
                    type: .rotation,
                    instructions: "Rotate 1/4 turn weekly for even growth",
                    frequencyDays: 7
                ))
                monstera.addCareStep(CareStep(
                    type: .dusting,
                    instructions: "Wipe leaves monthly to keep them clean and shiny",
                    frequencyDays: 30
                ))
                return monstera
            }(),
            {
                var zzPlant = Plant(
                    name: "ZZ Plant",
                    assignedRoomID: boxRoom.id,
                    assignedWindowID: boxRoom.windows.first?.id,
                    preferredLightDirection: .north,
                    lightType: .low,
                    generalNotes: "Extremely drought tolerant. Can handle low light areas well",
                    humidityPreference: .low
                )
                zzPlant.addCareStep(CareStep(
                    type: .watering,
                    instructions: "Water every 2-3 weeks, less in winter. Allow to dry completely between waterings",
                    frequencyDays: 21
                ))
                return zzPlant
            }(),
            {
                var spiderPlant = Plant(
                    name: "Spider Plant",
                    assignedRoomID: bathroom.id,
                    assignedWindowID: bathroom.windows.first?.id,
                    preferredLightDirection: .northeast,
                    lightType: .indirect,
                    generalNotes: "Produces plantlets that can be propagated. Benefits from bathroom humidity",
                    humidityPreference: .medium
                )
                spiderPlant.addCareStep(CareStep(
                    type: .watering,
                    instructions: "Water weekly, keeping soil lightly moist but not waterlogged",
                    frequencyDays: 7
                ))
                return spiderPlant
            }(),
            {
                var rubberPlant = Plant(
                    name: "Rubber Plant",
                    assignedRoomID: studio.id,
                    assignedWindowID: studio.windows.first?.id,
                    preferredLightDirection: .south,
                    lightType: .indirect,
                    generalNotes: "Can grow tall - prune to control height",
                    humidityPreference: .medium
                )
                rubberPlant.addCareStep(CareStep(
                    type: .watering,
                    instructions: "Water when top inch of soil is dry, reduce in winter",
                    frequencyDays: 10
                ))
                rubberPlant.addCareStep(CareStep(
                    type: .dusting,
                    instructions: "Wipe leaves to keep shiny",
                    frequencyDays: 14
                ))
                return rubberPlant
            }(),
            {
                var peaceLily = Plant(
                    name: "Peace Lily",
                    assignedRoomID: masterBedroom.id,
                    assignedWindowID: masterBedroom.windows.first { $0.direction == .northeast }?.id,
                    preferredLightDirection: .north,
                    lightType: .indirect,
                    generalNotes: "Drooping leaves indicate thirst. Remove spent flowers. Good air purifier",
                    humidityPreference: .high
                )
                peaceLily.addCareStep(CareStep(
                    type: .watering,
                    instructions: "Water when leaves start to droop slightly, about once a week",
                    frequencyDays: 7
                ))
                return peaceLily
            }(),
            {
                var philodendron = Plant(
                    name: "Philodendron",
                    assignedRoomID: spareBedroom.id,
                    assignedWindowID: spareBedroom.windows.first { $0.direction == .southeast }?.id,
                    preferredLightDirection: .east,
                    lightType: .indirect,
                    generalNotes: "Fast growing vine. Can be trained on moss pole or allowed to trail",
                    humidityPreference: .medium
                )
                philodendron.addCareStep(CareStep(
                    type: .watering,
                    instructions: "Water when top inch of soil is dry",
                    frequencyDays: 7
                ))
                return philodendron
            }(),
            {
                var aloeVera = Plant(
                    name: "Aloe Vera",
                    assignedRoomID: kitchen.id,
                    assignedWindowID: kitchen.windows.first?.id,
                    preferredLightDirection: .south,
                    lightType: .direct,
                    generalNotes: "Succulent - needs well-draining soil. Leaves contain healing gel",
                    humidityPreference: .low
                )
                aloeVera.addCareStep(CareStep(
                    type: .watering,
                    instructions: "Water every 2-3 weeks, allow soil to dry completely between waterings",
                    frequencyDays: 21
                ))
                return aloeVera
            }(),
            {
                var fiddleLeaf = Plant(
                    name: "Fiddle Leaf Fig",
                    assignedRoomID: livingRoom.id,
                    assignedWindowID: livingRoom.windows.first?.id,
                    preferredLightDirection: .east,
                    lightType: .indirect,
                    generalNotes: "Sensitive to overwatering. Responds well to consistent care",
                    humidityPreference: .medium
                )
                fiddleLeaf.addCareStep(CareStep(
                    type: .watering,
                    instructions: "Water when top 2 inches of soil are dry, typically weekly",
                    frequencyDays: 7
                ))
                fiddleLeaf.addCareStep(CareStep(
                    type: .rotation,
                    instructions: "Rotate 1/4 turn monthly for even growth",
                    frequencyDays: 30
                ))
                fiddleLeaf.addCareStep(CareStep(
                    type: .dusting,
                    instructions: "Dust leaves regularly to keep them healthy",
                    frequencyDays: 14
                ))
                return fiddleLeaf
            }()
        ]
        
        self.plants = defaultPlants
    }
    
    func addRoom(_ room: Room) {
        rooms.append(room)
        saveData()
    }
    
    func updateRoom(_ room: Room) {
        if let index = rooms.firstIndex(where: { $0.id == room.id }) {
            rooms[index] = room
            saveData()
        }
    }
    
    func deleteRoom(at offsets: IndexSet) {
        let roomsToDelete = offsets.map { rooms[$0] }
        for room in roomsToDelete {
            plants = plants.map { plant in
                if plant.assignedRoomID == room.id {
                    var updatedPlant = plant
                    updatedPlant.assignedRoomID = nil
                    updatedPlant.assignedWindowID = nil
                    return updatedPlant
                }
                return plant
            }
        }
        rooms.remove(atOffsets: offsets)
        saveData()
    }
    
    func moveRoom(from source: IndexSet, to destination: Int) {
        rooms.move(fromOffsets: source, toOffset: destination)
        for (index, room) in rooms.enumerated() {
            rooms[index].orderIndex = index
        }
        saveData()
    }
    
    func addZone(_ zone: Zone) {
        zones.append(zone)
        saveData()
    }
    
    func updateZone(_ zone: Zone) {
        if let index = zones.firstIndex(where: { $0.id == zone.id }) {
            zones[index] = zone
            saveData()
        }
    }
    
    func deleteZone(at offsets: IndexSet) {
        let zonesToDelete = offsets.map { zones[$0] }
        for zone in zonesToDelete {
            plants = plants.map { plant in
                if plant.assignedZoneID == zone.id {
                    var updatedPlant = plant
                    updatedPlant.assignedZoneID = nil
                    return updatedPlant
                }
                return plant
            }
        }
        zones.remove(atOffsets: offsets)
        saveData()
    }
    
    func moveZone(from source: IndexSet, to destination: Int) {
        zones.move(fromOffsets: source, toOffset: destination)
        for (index, zone) in zones.enumerated() {
            zones[index].orderIndex = index
        }
        saveData()
    }
    
    func addPlant(_ plant: Plant) {
        plants.append(plant)
        saveData()
    }
    
    func updatePlant(_ plant: Plant) {
        if let index = plants.firstIndex(where: { $0.id == plant.id }) {
            plants[index] = plant
            saveData()
            NotificationManager.shared.updateDailyReminders()
        }
    }
    
    func deletePlant(at offsets: IndexSet) {
        plants.remove(atOffsets: offsets)
        saveData()
    }
    
    func startCareSession() {
        currentCareSession = CareSession()
    }
    
    func markCareStepCompleted(plantID: UUID, careStepID: UUID) {
        currentCareSession?.markCareStepCompleted(plantID: plantID, careStepID: careStepID)
        if let plantIndex = plants.firstIndex(where: { $0.id == plantID }) {
            plants[plantIndex].markCareStepCompleted(withId: careStepID)
            saveData()
            NotificationManager.shared.updateDailyReminders()
        }
    }
    
    func unmarkCareStepCompleted(plantID: UUID, careStepID: UUID) {
        currentCareSession?.unmarkCareStepCompleted(plantID: plantID, careStepID: careStepID)
    }
    
    func endCareSession() {
        currentCareSession = nil
    }
    
    func plantsInRoom(_ room: Room) -> [Plant] {
        plants.filter { $0.assignedRoomID == room.id }
    }
    
    func plantsInZone(_ zone: Zone) -> [Plant] {
        plants.filter { $0.assignedZoneID == zone.id }
    }
    
    func roomForPlant(_ plant: Plant) -> Room? {
        guard let roomID = plant.assignedRoomID else { return nil }
        return rooms.first { $0.id == roomID }
    }
    
    func zoneForPlant(_ plant: Plant) -> Zone? {
        guard let zoneID = plant.assignedZoneID else { return nil }
        return zones.first { $0.id == zoneID }
    }
    
    func windowForPlant(_ plant: Plant) -> Window? {
        guard let roomID = plant.assignedRoomID,
              let windowID = plant.assignedWindowID,
              let room = rooms.first(where: { $0.id == roomID }) else { return nil }
        return room.windows.first { $0.id == windowID }
    }
    
    func allOverdueCareSteps() -> [(Plant, CareStep)] {
        var overdueSteps: [(Plant, CareStep)] = []
        for plant in plants {
            for step in plant.overdueCareSteps {
                overdueSteps.append((plant, step))
            }
        }
        return overdueSteps
    }
    
    func allDueTodayCareSteps() -> [(Plant, CareStep)] {
        var dueSteps: [(Plant, CareStep)] = []
        for plant in plants {
            for step in plant.dueTodayCareSteps {
                dueSteps.append((plant, step))
            }
        }
        return dueSteps
    }
    
    func plantsNeedingCare() -> [Plant] {
        plants.filter { plant in
            !plant.overdueCareSteps.isEmpty || !plant.dueTodayCareSteps.isEmpty
        }
    }
    
    func updateSettings(_ newSettings: AppSettings) {
        settings = newSettings
        saveData()
    }
    
    func orderedRoomsForCareRoutine() -> [Room] {
        if settings.customRoomOrder.isEmpty {
            return rooms
                .filter { room in plantsInRoom(room).count > 0 }
                .sorted(by: { $0.orderIndex < $1.orderIndex })
        } else {
            // Use custom order, but fall back to default for any missing rooms
            var orderedRooms: [Room] = []
            
            // Add rooms in custom order
            for roomID in settings.customRoomOrder {
                if let room = rooms.first(where: { $0.id == roomID }),
                   plantsInRoom(room).count > 0 {
                    orderedRooms.append(room)
                }
            }
            
            // Add any remaining rooms not in custom order
            let customOrderIDs = Set(settings.customRoomOrder)
            let remainingRooms = rooms.filter { room in
                !customOrderIDs.contains(room.id) && plantsInRoom(room).count > 0
            }.sorted(by: { $0.orderIndex < $1.orderIndex })
            
            orderedRooms.append(contentsOf: remainingRooms)
            
            return orderedRooms
        }
    }
    
    func orderedZonesForCareRoutine() -> [Zone] {
        return zones
            .filter { zone in plantsInZone(zone).count > 0 }
            .sorted(by: { $0.orderIndex < $1.orderIndex })
    }
}