import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        // Create model programmatically to avoid requiring a .xcdatamodeld file
        let model = NSManagedObjectModel()
        
        let entity = NSEntityDescription()
        entity.name = "FuelLog"
        entity.managedObjectClassName = NSStringFromClass(FuelLog.self)
        
        let idAttr = NSAttributeDescription()
        idAttr.name = "id"
        idAttr.attributeType = .UUIDAttributeType
        idAttr.isOptional = false
        
        let dateAttr = NSAttributeDescription()
        dateAttr.name = "date"
        dateAttr.attributeType = .dateAttributeType
        dateAttr.isOptional = false
        
        let odometerAttr = NSAttributeDescription()
        odometerAttr.name = "odometer"
        odometerAttr.attributeType = .doubleAttributeType
        odometerAttr.isOptional = false
        
        let volumeAttr = NSAttributeDescription()
        volumeAttr.name = "volume"
        volumeAttr.attributeType = .doubleAttributeType
        volumeAttr.isOptional = false
        
        let totalCostAttr = NSAttributeDescription()
        totalCostAttr.name = "totalCost"
        totalCostAttr.attributeType = .doubleAttributeType
        totalCostAttr.isOptional = false
        
        let stationNameAttr = NSAttributeDescription()
        stationNameAttr.name = "stationName"
        stationNameAttr.attributeType = .stringAttributeType
        stationNameAttr.isOptional = true
        
        let latAttr = NSAttributeDescription()
        latAttr.name = "latitude"
        latAttr.attributeType = .doubleAttributeType
        latAttr.isOptional = false
        
        let lonAttr = NSAttributeDescription()
        lonAttr.name = "longitude"
        lonAttr.attributeType = .doubleAttributeType
        lonAttr.isOptional = false
        
        entity.properties = [idAttr, dateAttr, odometerAttr, volumeAttr, totalCostAttr, stationNameAttr, latAttr, lonAttr]
        model.entities = [entity]
        
        container = NSPersistentContainer(name: "FuelMate", managedObjectModel: model)
        
        if inMemory {
            container.persistentStoreDescriptions.first!.url = URL(fileURLWithPath: "/dev/null")
        }
        
        container.loadPersistentStores { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
    }
}

// Programmatic definition of the FuelLog entity
@objc(FuelLog)
public class FuelLog: NSManagedObject, Identifiable {
    @NSManaged public var id: UUID
    @NSManaged public var date: Date
    @NSManaged public var odometer: Double
    @NSManaged public var volume: Double
    @NSManaged public var totalCost: Double
    @NSManaged public var stationName: String?
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
}
