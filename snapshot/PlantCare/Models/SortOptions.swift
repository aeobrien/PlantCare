import Foundation

enum SpacesSortOption: String, CaseIterable {
    case nameAscending = "A-Z"
    case nameDescending = "Z-A"
    case mostPlants = "Most Plants"
    case fewestPlants = "Fewest Plants"
    
    var systemImageName: String {
        switch self {
        case .nameAscending:
            return "arrow.up.circle"
        case .nameDescending:
            return "arrow.down.circle"
        case .mostPlants:
            return "arrow.up.circle.fill"
        case .fewestPlants:
            return "arrow.down.circle.fill"
        }
    }
}

enum PlantsSortOption: String, CaseIterable {
    case nameAscending = "A-Z"
    case nameDescending = "Z-A"
    case nextWateringDue = "Next Watering Due"
    case lastWateringDue = "Last Watering Due"
    case groupBySpaceAscending = "Group by Space (A-Z)"
    case groupBySpaceDescending = "Group by Space (Z-A)"
    
    var systemImageName: String {
        switch self {
        case .nameAscending:
            return "arrow.up.circle"
        case .nameDescending:
            return "arrow.down.circle"
        case .nextWateringDue:
            return "drop.circle"
        case .lastWateringDue:
            return "drop.circle.fill"
        case .groupBySpaceAscending:
            return "house.circle"
        case .groupBySpaceDescending:
            return "house.circle.fill"
        }
    }
}

// Extension to help with sorting plants
extension Array where Element == Plant {
    func sorted(by option: PlantsSortOption, dataStore: DataStore) -> [Plant] {
        switch option {
        case .nameAscending:
            return self.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .nameDescending:
            return self.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedDescending }
        case .nextWateringDue:
            return self.sorted { plant1, plant2 in
                let date1 = plant1.wateringStep?.nextDueDate ?? Date.distantFuture
                let date2 = plant2.wateringStep?.nextDueDate ?? Date.distantFuture
                return date1 < date2
            }
        case .lastWateringDue:
            return self.sorted { plant1, plant2 in
                let date1 = plant1.wateringStep?.nextDueDate ?? Date.distantPast
                let date2 = plant2.wateringStep?.nextDueDate ?? Date.distantPast
                return date1 > date2
            }
        case .groupBySpaceAscending:
            return self.sorted { plant1, plant2 in
                let space1 = dataStore.spaceNameForPlant(plant1)
                let space2 = dataStore.spaceNameForPlant(plant2)
                if space1 == space2 {
                    return plant1.name.localizedCaseInsensitiveCompare(plant2.name) == .orderedAscending
                }
                return space1.localizedCaseInsensitiveCompare(space2) == .orderedAscending
            }
        case .groupBySpaceDescending:
            return self.sorted { plant1, plant2 in
                let space1 = dataStore.spaceNameForPlant(plant1)
                let space2 = dataStore.spaceNameForPlant(plant2)
                if space1 == space2 {
                    return plant1.name.localizedCaseInsensitiveCompare(plant2.name) == .orderedAscending
                }
                return space1.localizedCaseInsensitiveCompare(space2) == .orderedDescending
            }
        }
    }
}

// Extension to help with space names
extension DataStore {
    func spaceNameForPlant(_ plant: Plant) -> String {
        if let room = roomForPlant(plant) {
            return room.name
        } else if let zone = zoneForPlant(plant) {
            return zone.name
        }
        return "Unassigned"
    }
    
}