import Foundation
import Combine

class DataStore: ObservableObject {
    static let shared = DataStore()
    
    @Published var rooms: [Room] = []
    @Published var plants: [Plant] = []
    @Published var currentCareSession: CareSession?
    
    private let roomsKey = "savedRooms"
    private let plantsKey = "savedPlants"
    
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
        
        if let plantsData = UserDefaults.standard.data(forKey: plantsKey),
           let decodedPlants = try? JSONDecoder().decode([Plant].self, from: plantsData) {
            self.plants = decodedPlants
        } else {
            loadDefaultPlants()
        }
    }
    
    func saveData() {
        if let encodedRooms = try? JSONEncoder().encode(rooms) {
            UserDefaults.standard.set(encodedRooms, forKey: roomsKey)
        }
        
        if let encodedPlants = try? JSONEncoder().encode(plants) {
            UserDefaults.standard.set(encodedPlants, forKey: plantsKey)
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
        
        let defaultPlants = [
            Plant(
                name: "Snake Plant",
                assignedRoomID: livingRoom.id,
                assignedWindowID: livingRoom.windows.first?.id,
                preferredLightDirection: .east,
                lightType: .indirect,
                wateringInstructions: "Water every 2-3 weeks, allowing soil to dry out between waterings",
                generalNotes: "Very tolerant of neglect. Can handle low light but prefers bright indirect light",
                wateringFrequencyDays: 14,
                humidityPreference: .low
            ),
            Plant(
                name: "Pothos",
                assignedRoomID: kitchen.id,
                assignedWindowID: kitchen.windows.first?.id,
                preferredLightDirection: .northeast,
                lightType: .indirect,
                wateringInstructions: "Water when top inch of soil is dry, typically once a week",
                generalNotes: "Fast growing, easy care. Trim to control size. Can propagate easily in water",
                wateringFrequencyDays: 7,
                humidityPreference: .medium
            ),
            Plant(
                name: "Monstera Deliciosa",
                assignedRoomID: livingRoom.id,
                assignedWindowID: livingRoom.windows.first?.id,
                preferredLightDirection: .east,
                lightType: .indirect,
                wateringInstructions: "Water when top 2 inches of soil are dry",
                generalNotes: "Needs support as it grows. Wipe leaves monthly. Benefits from occasional misting",
                wateringFrequencyDays: 10,
                humidityPreference: .high,
                rotationFrequency: "Rotate 1/4 turn weekly for even growth"
            ),
            Plant(
                name: "ZZ Plant",
                assignedRoomID: boxRoom.id,
                assignedWindowID: boxRoom.windows.first?.id,
                preferredLightDirection: .north,
                lightType: .low,
                wateringInstructions: "Water every 2-3 weeks, less in winter. Allow to dry completely between waterings",
                generalNotes: "Extremely drought tolerant. Can handle low light areas well",
                wateringFrequencyDays: 21,
                humidityPreference: .low
            ),
            Plant(
                name: "Spider Plant",
                assignedRoomID: bathroom.id,
                assignedWindowID: bathroom.windows.first?.id,
                preferredLightDirection: .northeast,
                lightType: .indirect,
                wateringInstructions: "Water weekly, keeping soil lightly moist but not waterlogged",
                generalNotes: "Produces plantlets that can be propagated. Benefits from bathroom humidity",
                wateringFrequencyDays: 7,
                humidityPreference: .medium
            ),
            Plant(
                name: "Rubber Plant",
                assignedRoomID: studio.id,
                assignedWindowID: studio.windows.first?.id,
                preferredLightDirection: .south,
                lightType: .indirect,
                wateringInstructions: "Water when top inch of soil is dry, reduce in winter",
                generalNotes: "Wipe leaves to keep shiny. Can grow tall - prune to control height",
                wateringFrequencyDays: 10,
                humidityPreference: .medium
            ),
            Plant(
                name: "Peace Lily",
                assignedRoomID: masterBedroom.id,
                assignedWindowID: masterBedroom.windows.first { $0.direction == .northeast }?.id,
                preferredLightDirection: .north,
                lightType: .indirect,
                wateringInstructions: "Water when leaves start to droop slightly, about once a week",
                generalNotes: "Drooping leaves indicate thirst. Remove spent flowers. Good air purifier",
                wateringFrequencyDays: 7,
                humidityPreference: .high
            ),
            Plant(
                name: "Philodendron",
                assignedRoomID: spareBedroom.id,
                assignedWindowID: spareBedroom.windows.first { $0.direction == .southeast }?.id,
                preferredLightDirection: .east,
                lightType: .indirect,
                wateringInstructions: "Water when top inch of soil is dry",
                generalNotes: "Fast growing vine. Can be trained on moss pole or allowed to trail",
                wateringFrequencyDays: 7,
                humidityPreference: .medium
            ),
            Plant(
                name: "Aloe Vera",
                assignedRoomID: kitchen.id,
                assignedWindowID: kitchen.windows.first?.id,
                preferredLightDirection: .south,
                lightType: .direct,
                wateringInstructions: "Water every 2-3 weeks, allow soil to dry completely between waterings",
                generalNotes: "Succulent - needs well-draining soil. Leaves contain healing gel",
                wateringFrequencyDays: 21,
                humidityPreference: .low
            ),
            Plant(
                name: "Fiddle Leaf Fig",
                assignedRoomID: livingRoom.id,
                assignedWindowID: livingRoom.windows.first?.id,
                preferredLightDirection: .east,
                lightType: .indirect,
                wateringInstructions: "Water when top 2 inches of soil are dry, typically weekly",
                generalNotes: "Sensitive to overwatering. Rotate monthly for even growth. Dust leaves regularly",
                wateringFrequencyDays: 7,
                humidityPreference: .medium,
                rotationFrequency: "Rotate 1/4 turn monthly"
            )
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
    
    func addPlant(_ plant: Plant) {
        plants.append(plant)
        saveData()
    }
    
    func updatePlant(_ plant: Plant) {
        if let index = plants.firstIndex(where: { $0.id == plant.id }) {
            plants[index] = plant
            saveData()
        }
    }
    
    func deletePlant(at offsets: IndexSet) {
        plants.remove(atOffsets: offsets)
        saveData()
    }
    
    func startCareSession() {
        currentCareSession = CareSession()
    }
    
    func markPlantAsCaredFor(plantID: UUID) {
        currentCareSession?.completedPlantIDs.insert(plantID)
        if let plant = plants.first(where: { $0.id == plantID }) {
            var updatedPlant = plant
            updatedPlant.lastWateredDate = Date()
            updatePlant(updatedPlant)
        }
    }
    
    func endCareSession() {
        currentCareSession = nil
    }
    
    func plantsInRoom(_ room: Room) -> [Plant] {
        plants.filter { $0.assignedRoomID == room.id }
    }
    
    func roomForPlant(_ plant: Plant) -> Room? {
        guard let roomID = plant.assignedRoomID else { return nil }
        return rooms.first { $0.id == roomID }
    }
    
    func windowForPlant(_ plant: Plant) -> Window? {
        guard let roomID = plant.assignedRoomID,
              let windowID = plant.assignedWindowID,
              let room = rooms.first(where: { $0.id == roomID }) else { return nil }
        return room.windows.first { $0.id == windowID }
    }
}