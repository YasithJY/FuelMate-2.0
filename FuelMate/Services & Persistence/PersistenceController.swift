import Foundation
import CoreData

// MARK: - Fuel Tracking Mode Enum
public enum FuelTrackingMode: String, CaseIterable, Identifiable {
    case levelTracked = "levelTracked"
    case expensesOnly = "expensesOnly"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .levelTracked:
            return "I can check remaining fuel level"
        case .expensesOnly:
            return "I can't check remaining fuel level"
        }
    }
    
    public var shortBadge: String {
        switch self {
        case .levelTracked:
            return "Consumption"
        case .expensesOnly:
            return "Expenses only"
        }
    }
    
    public var subtitle: String {
        switch self {
        case .levelTracked:
            return "Shows fuel consumption, efficiency gauge, sparkline, and benchmarks. Requires tank capacity and City/Highway baselines."
        case .expensesOnly:
            return "Expenses only. Tracks spending, distance, and fuel cost without consumption calculations."
        }
    }
}

// MARK: - Core Data Persistence Controller (Multi-Entity Programmatic Model)
public struct PersistenceController {
    public static let shared = PersistenceController()
    
    // Preview instance configured for in-memory testing & SwiftUI canvas
    public static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let viewContext = controller.container.viewContext
        
        let sampleVehicle = Vehicle(context: viewContext)
        sampleVehicle.id = UUID()
        sampleVehicle.name = "Toyota Prius"
        sampleVehicle.plateNumber = "WP CAB-2045"
        sampleVehicle.vehicleType = "Car"
        sampleVehicle.tankCapacity = 45.0
        sampleVehicle.tankCapacityLiters = NSNumber(value: 45.0)
        sampleVehicle.fuelTrackingMode = FuelTrackingMode.levelTracked.rawValue
        sampleVehicle.initialOdometer = 45000.0
        sampleVehicle.cityFuelConsumption = 18.0
        sampleVehicle.highwayFuelConsumption = 22.0
        
        let sampleLog1 = FuelLog(context: viewContext)
        sampleLog1.id = UUID()
        sampleLog1.date = Calendar.current.date(byAdding: .day, value: -10, to: Date()) ?? Date()
        sampleLog1.odometer = 45350.0
        sampleLog1.volume = 20.0
        sampleLog1.totalCost = NSDecimalNumber(value: 6220.0)
        sampleLog1.stationName = "Ceypetco"
        sampleLog1.fuelGrade = "Petrol Octane 92"
        sampleLog1.tripType = "City"
        sampleLog1.isFullTank = true
        sampleLog1.fuelLevelBefore = 0.30
        sampleLog1.notes = "Full tank at Colombo filling shed"
        sampleLog1.latitude = 6.9271
        sampleLog1.longitude = 79.8612
        sampleLog1.locality = "Colombo 07"
        sampleLog1.vehicle = sampleVehicle
        
        let sampleLog2 = FuelLog(context: viewContext)
        sampleLog2.id = UUID()
        sampleLog2.date = Date()
        sampleLog2.odometer = 45720.0
        sampleLog2.volume = 19.5
        sampleLog2.totalCost = NSDecimalNumber(value: 6064.5)
        sampleLog2.stationName = "Lanka IOC"
        sampleLog2.fuelGrade = "Petrol Octane 92"
        sampleLog2.tripType = "Highway"
        sampleLog2.isFullTank = true
        sampleLog2.fuelLevelBefore = 0.25
        sampleLog2.notes = "Kandy expressway refill"
        sampleLog2.latitude = 7.2906
        sampleLog2.longitude = 80.6337
        sampleLog2.locality = "Kandy"
        sampleLog2.vehicle = sampleVehicle
        
        do {
            try viewContext.save()
        } catch {
            print("Preview Core Data save failed: \(error.localizedDescription)")
        }
        return controller
    }()
    
    public let container: NSPersistentContainer
    
    // MARK: - Programmatic Model Construction (V2: with Fuel Level & Mode Tracking)
    public static func createModel() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        
        // Entity 1: Vehicle
        let vehicleEntity = NSEntityDescription()
        vehicleEntity.name = "Vehicle"
        vehicleEntity.managedObjectClassName = NSStringFromClass(Vehicle.self)
        
        let vIdAttr = NSAttributeDescription()
        vIdAttr.name = "id"
        vIdAttr.attributeType = .UUIDAttributeType
        vIdAttr.isOptional = false
        
        let vNameAttr = NSAttributeDescription()
        vNameAttr.name = "name"
        vNameAttr.attributeType = .stringAttributeType
        vNameAttr.isOptional = false
        vNameAttr.defaultValue = "My Vehicle"
        
        let vPlateAttr = NSAttributeDescription()
        vPlateAttr.name = "plateNumber"
        vPlateAttr.attributeType = .stringAttributeType
        vPlateAttr.isOptional = true
        
        let vTypeAttr = NSAttributeDescription()
        vTypeAttr.name = "vehicleType"
        vTypeAttr.attributeType = .stringAttributeType
        vTypeAttr.isOptional = false
        vTypeAttr.defaultValue = "Car"
        
        let vTankAttr = NSAttributeDescription()
        vTankAttr.name = "tankCapacity"
        vTankAttr.attributeType = .doubleAttributeType
        vTankAttr.isOptional = false
        vTankAttr.defaultValue = 45.0
        
        let vTankCapacityLitersAttr = NSAttributeDescription()
        vTankCapacityLitersAttr.name = "tankCapacityLiters"
        vTankCapacityLitersAttr.attributeType = .doubleAttributeType
        vTankCapacityLitersAttr.isOptional = true
        
        let vModeAttr = NSAttributeDescription()
        vModeAttr.name = "fuelTrackingMode"
        vModeAttr.attributeType = .stringAttributeType
        vModeAttr.isOptional = true
        vModeAttr.defaultValue = FuelTrackingMode.levelTracked.rawValue
        
        let vInitialOdoAttr = NSAttributeDescription()
        vInitialOdoAttr.name = "initialOdometer"
        vInitialOdoAttr.attributeType = .doubleAttributeType
        vInitialOdoAttr.isOptional = false
        vInitialOdoAttr.defaultValue = 0.0
        
        let vCityFuelAttr = NSAttributeDescription()
        vCityFuelAttr.name = "cityFuelConsumption"
        vCityFuelAttr.attributeType = .doubleAttributeType
        vCityFuelAttr.isOptional = false
        vCityFuelAttr.defaultValue = 10.0
        
        let vHighwayFuelAttr = NSAttributeDescription()
        vHighwayFuelAttr.name = "highwayFuelConsumption"
        vHighwayFuelAttr.attributeType = .doubleAttributeType
        vHighwayFuelAttr.isOptional = false
        vHighwayFuelAttr.defaultValue = 15.0
        
        // Entity 2: FuelLog
        let fuelLogEntity = NSEntityDescription()
        fuelLogEntity.name = "FuelLog"
        fuelLogEntity.managedObjectClassName = NSStringFromClass(FuelLog.self)
        
        let logIdAttr = NSAttributeDescription()
        logIdAttr.name = "id"
        logIdAttr.attributeType = .UUIDAttributeType
        logIdAttr.isOptional = false
        
        let logDateAttr = NSAttributeDescription()
        logDateAttr.name = "date"
        logDateAttr.attributeType = .dateAttributeType
        logDateAttr.isOptional = false
        
        let logOdoAttr = NSAttributeDescription()
        logOdoAttr.name = "odometer"
        logOdoAttr.attributeType = .doubleAttributeType
        logOdoAttr.isOptional = false
        logOdoAttr.defaultValue = 0.0
        
        let logVolAttr = NSAttributeDescription()
        logVolAttr.name = "volume"
        logVolAttr.attributeType = .doubleAttributeType
        logVolAttr.isOptional = false
        logVolAttr.defaultValue = 0.0
        
        let logTotalCostAttr = NSAttributeDescription()
        logTotalCostAttr.name = "totalCost"
        logTotalCostAttr.attributeType = .decimalAttributeType
        logTotalCostAttr.isOptional = false
        logTotalCostAttr.defaultValue = NSDecimalNumber.zero
        
        let logStationNameAttr = NSAttributeDescription()
        logStationNameAttr.name = "stationName"
        logStationNameAttr.attributeType = .stringAttributeType
        logStationNameAttr.isOptional = true
        
        let logFuelGradeAttr = NSAttributeDescription()
        logFuelGradeAttr.name = "fuelGrade"
        logFuelGradeAttr.attributeType = .stringAttributeType
        logFuelGradeAttr.isOptional = true
        
        let logTripTypeAttr = NSAttributeDescription()
        logTripTypeAttr.name = "tripType"
        logTripTypeAttr.attributeType = .stringAttributeType
        logTripTypeAttr.isOptional = false
        logTripTypeAttr.defaultValue = "City"
        
        let logIsFullTankAttr = NSAttributeDescription()
        logIsFullTankAttr.name = "isFullTank"
        logIsFullTankAttr.attributeType = .booleanAttributeType
        logIsFullTankAttr.isOptional = false
        logIsFullTankAttr.defaultValue = true
        
        let logNotesAttr = NSAttributeDescription()
        logNotesAttr.name = "notes"
        logNotesAttr.attributeType = .stringAttributeType
        logNotesAttr.isOptional = true
        
        let logLatAttr = NSAttributeDescription()
        logLatAttr.name = "latitude"
        logLatAttr.attributeType = .doubleAttributeType
        logLatAttr.isOptional = false
        logLatAttr.defaultValue = 0.0
        
        let logLonAttr = NSAttributeDescription()
        logLonAttr.name = "longitude"
        logLonAttr.attributeType = .doubleAttributeType
        logLonAttr.isOptional = false
        logLonAttr.defaultValue = 0.0
        
        let logLocalityAttr = NSAttributeDescription()
        logLocalityAttr.name = "locality"
        logLocalityAttr.attributeType = .stringAttributeType
        logLocalityAttr.isOptional = true
        
        let logRemainingFuelAttr = NSAttributeDescription()
        logRemainingFuelAttr.name = "remainingFuelPercentBefore"
        logRemainingFuelAttr.attributeType = .doubleAttributeType
        logRemainingFuelAttr.isOptional = true
        
        let logExcludedAttr = NSAttributeDescription()
        logExcludedAttr.name = "isExcludedFromConsumption"
        logExcludedAttr.attributeType = .booleanAttributeType
        logExcludedAttr.isOptional = true
        logExcludedAttr.defaultValue = false
        
        // Relationships
        let vehicleLogsRel = NSRelationshipDescription()
        vehicleLogsRel.name = "logs"
        vehicleLogsRel.destinationEntity = fuelLogEntity
        vehicleLogsRel.minCount = 0
        vehicleLogsRel.maxCount = 0 // To-many
        vehicleLogsRel.deleteRule = .cascadeDeleteRule
        vehicleLogsRel.isOptional = true
        
        let fuelLogVehicleRel = NSRelationshipDescription()
        fuelLogVehicleRel.name = "vehicle"
        fuelLogVehicleRel.destinationEntity = vehicleEntity
        fuelLogVehicleRel.minCount = 0
        fuelLogVehicleRel.maxCount = 1 // To-one
        fuelLogVehicleRel.deleteRule = .nullifyDeleteRule
        fuelLogVehicleRel.isOptional = true
        
        vehicleLogsRel.inverseRelationship = fuelLogVehicleRel
        fuelLogVehicleRel.inverseRelationship = vehicleLogsRel
        
        // Properties assignment
        vehicleEntity.properties = [
            vIdAttr, vNameAttr, vPlateAttr, vTypeAttr, vTankAttr, vTankCapacityLitersAttr,
            vModeAttr, vInitialOdoAttr, vCityFuelAttr, vHighwayFuelAttr, vehicleLogsRel
        ]
        
        fuelLogEntity.properties = [
            logIdAttr, logDateAttr, logOdoAttr, logVolAttr, logTotalCostAttr,
            logStationNameAttr, logFuelGradeAttr, logTripTypeAttr, logIsFullTankAttr, logNotesAttr,
            logLatAttr, logLonAttr, logLocalityAttr, logRemainingFuelAttr, logExcludedAttr, fuelLogVehicleRel
        ]
        
        // Indexes
        let vIdIndexElem = NSFetchIndexElementDescription(property: vIdAttr, collationType: .binary)
        let vIdIndex = NSFetchIndexDescription(name: "vehicle_id_idx", elements: [vIdIndexElem])
        vehicleEntity.indexes = [vIdIndex]
        
        let logIdIndexElem = NSFetchIndexElementDescription(property: logIdAttr, collationType: .binary)
        let logIdIndex = NSFetchIndexDescription(name: "fuel_log_id_idx", elements: [logIdIndexElem])
        let logDateIndexElem = NSFetchIndexElementDescription(property: logDateAttr, collationType: .binary)
        let logDateIndex = NSFetchIndexDescription(name: "fuel_log_date_idx", elements: [logDateIndexElem])
        fuelLogEntity.indexes = [logIdIndex, logDateIndex]
        
        model.entities = [vehicleEntity, fuelLogEntity]
        return model
    }
    
    // MARK: - Programmatic V1 Model (For Migrating Existing Stores)
    public static func createV1Model() -> NSManagedObjectModel {
        let model = NSManagedObjectModel()
        
        let vehicleEntity = NSEntityDescription()
        vehicleEntity.name = "Vehicle"
        vehicleEntity.managedObjectClassName = NSStringFromClass(Vehicle.self)
        
        let vIdAttr = NSAttributeDescription()
        vIdAttr.name = "id"
        vIdAttr.attributeType = .UUIDAttributeType
        vIdAttr.isOptional = false
        
        let vNameAttr = NSAttributeDescription()
        vNameAttr.name = "name"
        vNameAttr.attributeType = .stringAttributeType
        vNameAttr.isOptional = false
        vNameAttr.defaultValue = "My Vehicle"
        
        let vPlateAttr = NSAttributeDescription()
        vPlateAttr.name = "plateNumber"
        vPlateAttr.attributeType = .stringAttributeType
        vPlateAttr.isOptional = true
        
        let vTypeAttr = NSAttributeDescription()
        vTypeAttr.name = "vehicleType"
        vTypeAttr.attributeType = .stringAttributeType
        vTypeAttr.isOptional = false
        vTypeAttr.defaultValue = "Car"
        
        let vTankAttr = NSAttributeDescription()
        vTankAttr.name = "tankCapacity"
        vTankAttr.attributeType = .doubleAttributeType
        vTankAttr.isOptional = false
        vTankAttr.defaultValue = 45.0
        
        let vInitialOdoAttr = NSAttributeDescription()
        vInitialOdoAttr.name = "initialOdometer"
        vInitialOdoAttr.attributeType = .doubleAttributeType
        vInitialOdoAttr.isOptional = false
        vInitialOdoAttr.defaultValue = 0.0
        
        let vCityFuelAttr = NSAttributeDescription()
        vCityFuelAttr.name = "cityFuelConsumption"
        vCityFuelAttr.attributeType = .doubleAttributeType
        vCityFuelAttr.isOptional = false
        vCityFuelAttr.defaultValue = 10.0
        
        let vHighwayFuelAttr = NSAttributeDescription()
        vHighwayFuelAttr.name = "highwayFuelConsumption"
        vHighwayFuelAttr.attributeType = .doubleAttributeType
        vHighwayFuelAttr.isOptional = false
        vHighwayFuelAttr.defaultValue = 15.0
        
        let fuelLogEntity = NSEntityDescription()
        fuelLogEntity.name = "FuelLog"
        fuelLogEntity.managedObjectClassName = NSStringFromClass(FuelLog.self)
        
        let logIdAttr = NSAttributeDescription()
        logIdAttr.name = "id"
        logIdAttr.attributeType = .UUIDAttributeType
        logIdAttr.isOptional = false
        
        let logDateAttr = NSAttributeDescription()
        logDateAttr.name = "date"
        logDateAttr.attributeType = .dateAttributeType
        logDateAttr.isOptional = false
        
        let logOdoAttr = NSAttributeDescription()
        logOdoAttr.name = "odometer"
        logOdoAttr.attributeType = .doubleAttributeType
        logOdoAttr.isOptional = false
        logOdoAttr.defaultValue = 0.0
        
        let logVolAttr = NSAttributeDescription()
        logVolAttr.name = "volume"
        logVolAttr.attributeType = .doubleAttributeType
        logVolAttr.isOptional = false
        logVolAttr.defaultValue = 0.0
        
        let logTotalCostAttr = NSAttributeDescription()
        logTotalCostAttr.name = "totalCost"
        logTotalCostAttr.attributeType = .decimalAttributeType
        logTotalCostAttr.isOptional = false
        logTotalCostAttr.defaultValue = NSDecimalNumber.zero
        
        let logStationNameAttr = NSAttributeDescription()
        logStationNameAttr.name = "stationName"
        logStationNameAttr.attributeType = .stringAttributeType
        logStationNameAttr.isOptional = true
        
        let logFuelGradeAttr = NSAttributeDescription()
        logFuelGradeAttr.name = "fuelGrade"
        logFuelGradeAttr.attributeType = .stringAttributeType
        logFuelGradeAttr.isOptional = true
        
        let logTripTypeAttr = NSAttributeDescription()
        logTripTypeAttr.name = "tripType"
        logTripTypeAttr.attributeType = .stringAttributeType
        logTripTypeAttr.isOptional = false
        logTripTypeAttr.defaultValue = "City"
        
        let logIsFullTankAttr = NSAttributeDescription()
        logIsFullTankAttr.name = "isFullTank"
        logIsFullTankAttr.attributeType = .booleanAttributeType
        logIsFullTankAttr.isOptional = false
        logIsFullTankAttr.defaultValue = true
        
        let logNotesAttr = NSAttributeDescription()
        logNotesAttr.name = "notes"
        logNotesAttr.attributeType = .stringAttributeType
        logNotesAttr.isOptional = true
        
        let logLatAttr = NSAttributeDescription()
        logLatAttr.name = "latitude"
        logLatAttr.attributeType = .doubleAttributeType
        logLatAttr.isOptional = false
        logLatAttr.defaultValue = 0.0
        
        let logLonAttr = NSAttributeDescription()
        logLonAttr.name = "longitude"
        logLonAttr.attributeType = .doubleAttributeType
        logLonAttr.isOptional = false
        logLonAttr.defaultValue = 0.0
        
        let logLocalityAttr = NSAttributeDescription()
        logLocalityAttr.name = "locality"
        logLocalityAttr.attributeType = .stringAttributeType
        logLocalityAttr.isOptional = true
        
        let vehicleLogsRel = NSRelationshipDescription()
        vehicleLogsRel.name = "logs"
        vehicleLogsRel.destinationEntity = fuelLogEntity
        vehicleLogsRel.minCount = 0
        vehicleLogsRel.maxCount = 0
        vehicleLogsRel.deleteRule = .cascadeDeleteRule
        vehicleLogsRel.isOptional = true
        
        let fuelLogVehicleRel = NSRelationshipDescription()
        fuelLogVehicleRel.name = "vehicle"
        fuelLogVehicleRel.destinationEntity = vehicleEntity
        fuelLogVehicleRel.minCount = 0
        fuelLogVehicleRel.maxCount = 1
        fuelLogVehicleRel.deleteRule = .nullifyDeleteRule
        fuelLogVehicleRel.isOptional = true
        
        vehicleLogsRel.inverseRelationship = fuelLogVehicleRel
        fuelLogVehicleRel.inverseRelationship = vehicleLogsRel
        
        vehicleEntity.properties = [
            vIdAttr, vNameAttr, vPlateAttr, vTypeAttr, vTankAttr, vInitialOdoAttr,
            vCityFuelAttr, vHighwayFuelAttr, vehicleLogsRel
        ]
        
        fuelLogEntity.properties = [
            logIdAttr, logDateAttr, logOdoAttr, logVolAttr, logTotalCostAttr,
            logStationNameAttr, logFuelGradeAttr, logTripTypeAttr, logIsFullTankAttr, logNotesAttr,
            logLatAttr, logLonAttr, logLocalityAttr, fuelLogVehicleRel
        ]
        
        let vIdIndexElem = NSFetchIndexElementDescription(property: vIdAttr, collationType: .binary)
        let vIdIndex = NSFetchIndexDescription(name: "vehicle_id_idx", elements: [vIdIndexElem])
        vehicleEntity.indexes = [vIdIndex]
        
        let logIdIndexElem = NSFetchIndexElementDescription(property: logIdAttr, collationType: .binary)
        let logIdIndex = NSFetchIndexDescription(name: "fuel_log_id_idx", elements: [logIdIndexElem])
        let logDateIndexElem = NSFetchIndexElementDescription(property: logDateAttr, collationType: .binary)
        let logDateIndex = NSFetchIndexDescription(name: "fuel_log_date_idx", elements: [logDateIndexElem])
        fuelLogEntity.indexes = [logIdIndex, logDateIndex]
        
        model.entities = [vehicleEntity, fuelLogEntity]
        return model
    }
    
    // MARK: - Safe V1 to V2 Store Migration
    public static func migrateStoreIfNeeded(at storeURL: URL) {
        guard FileManager.default.fileExists(atPath: storeURL.path) else { return }
        guard let metadata = try? NSPersistentStoreCoordinator.metadataForPersistentStore(ofType: NSSQLiteStoreType, at: storeURL, options: nil) else { return }
        
        let v2Model = createModel()
        if v2Model.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata) {
            // Already compatible, no migration needed
            return
        }
        
        let v1Model = createV1Model()
        if v1Model.isConfiguration(withName: nil, compatibleWithStoreMetadata: metadata) {
            do {
                let mapping = try NSMappingModel.inferredMappingModel(forSourceModel: v1Model, destinationModel: v2Model)
                let tempURL = storeURL.deletingLastPathComponent().appendingPathComponent("FuelMate_v2_migrated.sqlite")
                try? FileManager.default.removeItem(at: tempURL)
                try? FileManager.default.removeItem(at: tempURL.appendingPathExtension("shm"))
                try? FileManager.default.removeItem(at: tempURL.appendingPathExtension("wal"))
                
                let manager = NSMigrationManager(sourceModel: v1Model, destinationModel: v2Model)
                try manager.migrateStore(
                    from: storeURL,
                    sourceType: NSSQLiteStoreType,
                    options: nil,
                    with: mapping,
                    toDestinationURL: tempURL,
                    destinationType: NSSQLiteStoreType,
                    destinationOptions: nil
                )
                
                let coordinator = NSPersistentStoreCoordinator(managedObjectModel: v2Model)
                try coordinator.replacePersistentStore(
                    at: storeURL,
                    destinationOptions: nil,
                    withPersistentStoreFrom: tempURL,
                    sourceOptions: nil,
                    ofType: NSSQLiteStoreType
                )
                try? FileManager.default.removeItem(at: tempURL)
                try? FileManager.default.removeItem(at: tempURL.appendingPathExtension("shm"))
                try? FileManager.default.removeItem(at: tempURL.appendingPathExtension("wal"))
                print("Successfully performed safe programmatic migration from V1 to V2 store.")
            } catch {
                print("Programmatic store migration error: \(error.localizedDescription)")
            }
        }
    }
    
    public init(inMemory: Bool = false) {
        let model = PersistenceController.createModel()
        let persistentContainer = NSPersistentContainer(name: "FuelMate", managedObjectModel: model)
        
        if inMemory {
            persistentContainer.persistentStoreDescriptions.first?.url = URL(fileURLWithPath: "/dev/null")
        } else {
            persistentContainer.persistentStoreDescriptions.first?.setOption(true as NSNumber, forKey: NSMigratePersistentStoresAutomaticallyOption)
            persistentContainer.persistentStoreDescriptions.first?.setOption(true as NSNumber, forKey: NSInferMappingModelAutomaticallyOption)
            
            if let storeURL = persistentContainer.persistentStoreDescriptions.first?.url {
                PersistenceController.migrateStoreIfNeeded(at: storeURL)
            }
        }
        
        persistentContainer.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                print("Core Data load store warning: \(error.localizedDescription).")
            }
        }
        
        persistentContainer.viewContext.automaticallyMergesChangesFromParent = true
        persistentContainer.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        self.container = persistentContainer
    }
    
    public func saveContext() {
        let context = container.viewContext
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            print("Failed to save viewContext: \(error.localizedDescription)")
        }
    }
}

// MARK: - Programmatic Vehicle NSManagedObject
@objc(Vehicle)
public class Vehicle: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var name: String
    @NSManaged public var plateNumber: String?
    @NSManaged public var vehicleType: String
    @NSManaged public var tankCapacity: Double
    @NSManaged public var tankCapacityLiters: NSNumber?
    @NSManaged public var fuelTrackingMode: String?
    @NSManaged public var initialOdometer: Double
    @NSManaged public var cityFuelConsumption: Double
    @NSManaged public var highwayFuelConsumption: Double
    @NSManaged public var logs: NSSet?
    
    public var trackingMode: FuelTrackingMode {
        get {
            guard let raw = fuelTrackingMode, let mode = FuelTrackingMode(rawValue: raw) else {
                return .levelTracked
            }
            return mode
        }
        set {
            fuelTrackingMode = newValue.rawValue
        }
    }
    
    public var isLevelTracked: Bool {
        trackingMode == .levelTracked
    }
    
    public var effectiveTankCapacity: Double {
        if let cap = tankCapacityLiters?.doubleValue, cap > 0 {
            return cap
        }
        return tankCapacity > 0 ? tankCapacity : 45.0
    }
    
    public var sortedLogs: [FuelLog] {
        let set = logs as? Set<FuelLog> ?? []
        return set.sorted { $0.date > $1.date }
    }
    
    public var fuelLogs: [FuelLog] {
        sortedLogs
    }
    
    public var iconName: String {
        SriLankanEcosystem.vehicleTypeIcons[vehicleType] ?? "car.side.fill"
    }
    
    public var displayName: String {
        if let plate = plateNumber, !plate.isEmpty {
            return "\(name) (\(plate))"
        }
        return name
    }
    
    public var effectiveCityConsumption: Double {
        cityFuelConsumption > 0 ? cityFuelConsumption : 10.0
    }
    
    public var effectiveHighwayConsumption: Double {
        highwayFuelConsumption > 0 ? highwayFuelConsumption : 15.0
    }
}

// MARK: - Programmatic FuelLog NSManagedObject
@objc(FuelLog)
public class FuelLog: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var date: Date
    @NSManaged public var odometer: Double
    @NSManaged public var volume: Double
    @NSManaged public var totalCost: NSDecimalNumber?
    @NSManaged public var stationName: String?
    @NSManaged public var fuelGrade: String?
    @NSManaged public var tripType: String
    @NSManaged public var isFullTank: Bool
    @NSManaged public var notes: String?
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var locality: String?
    @NSManaged public var vehicle: Vehicle?
    @NSManaged public var remainingFuelPercentBefore: NSNumber?
    @NSManaged public var isExcludedFromConsumption: NSNumber?
    
    public var fuelLevelBefore: Double? {
        get { remainingFuelPercentBefore?.doubleValue }
        set { remainingFuelPercentBefore = newValue.map { NSNumber(value: $0) } }
    }
    
    public var isExcluded: Bool {
        get { isExcludedFromConsumption?.boolValue ?? false }
        set { isExcludedFromConsumption = NSNumber(value: newValue) }
    }
    
    public var costDecimal: Decimal {
        get { (totalCost as Decimal?) ?? Decimal.zero }
        set { totalCost = NSDecimalNumber(decimal: newValue) }
    }
    
    public var totalCostDecimal: Decimal {
        costDecimal
    }
    
    public var totalCostDouble: Double {
        totalCost?.doubleValue ?? 0.0
    }
    
    public var hasValidLocation: Bool {
        return latitude != 0.0 && longitude != 0.0
    }
    
    public var unitPriceDecimal: Decimal {
        guard volume > 0 else { return .zero }
        return costDecimal / Decimal(volume)
    }
    
    public var unitPrice: Double {
        guard volume > 0 else { return 0.0 }
        return totalCostDouble / volume
    }
    
    public var fuelType: String? {
        return fuelGrade
    }
    
    public var fullTankValue: Bool {
        return isFullTank
    }
    
    public var effectiveTripType: String {
        return tripType.isEmpty ? "City" : tripType
    }
    
    public func toFuelEntry() -> FuelEntry {
        return FuelEntry(
            id: id,
            date: date,
            odometer: odometer,
            volume: volume,
            totalCost: costDecimal,
            isFullTank: isFullTank,
            tripType: effectiveTripType,
            stationName: stationName ?? "",
            fuelGrade: fuelGrade ?? "",
            fuelLevelBefore: fuelLevelBefore,
            isExcluded: isExcluded
        )
    }
}
