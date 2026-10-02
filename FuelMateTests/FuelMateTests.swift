import XCTest
@testable import FuelMate
import CoreData

final class FuelMateTests: XCTestCase {

    var persistenceController: PersistenceController!
    var context: NSManagedObjectContext!

    override func setUpWithError() throws {
        try super.setUpWithError()
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.container.viewContext
    }

    override func tearDownWithError() throws {
        persistenceController = nil
        context = nil
        try super.tearDownWithError()
    }

    // MARK: - Core Data & Relationship Tests
    func testVehicleAndFuelLogRelationship() throws {
        let vehicle = Vehicle(context: context)
        vehicle.id = UUID()
        vehicle.name = "Toyota Prius"
        vehicle.plateNumber = "WP CAB-2045"
        vehicle.vehicleType = "Car"
        vehicle.tankCapacity = 45.0
        vehicle.initialOdometer = 45000.0
        vehicle.cityFuelConsumption = 18.0
        vehicle.highwayFuelConsumption = 22.0

        let log = FuelLog(context: context)
        log.id = UUID()
        log.date = Date()
        log.odometer = 45450.0
        log.volume = 20.0
        log.totalCost = NSDecimalNumber(value: 6220.0)
        log.stationName = "Ceypetco"
        log.fuelGrade = "Petrol Octane 92"
        log.tripType = "City"
        log.isFullTank = true
        log.vehicle = vehicle

        try context.save()

        XCTAssertEqual(vehicle.fuelLogs.count, 1)
        XCTAssertEqual(vehicle.fuelLogs.first?.stationName, "Ceypetco")
        XCTAssertEqual(vehicle.cityFuelConsumption, 18.0)
        XCTAssertEqual(vehicle.highwayFuelConsumption, 22.0)
        XCTAssertEqual(vehicle.fuelLogs.first?.tripType, "City")
        let price = try XCTUnwrap(vehicle.fuelLogs.first?.unitPrice)
        XCTAssertEqual(price, 311.0, accuracy: 0.1)
        XCTAssertEqual(log.vehicle?.name, "Toyota Prius")
    }

    // MARK: - Dynamic Fuel Price Engine Tests
    func testFuelPriceManagerLookups() {
        let manager = FuelPriceManager.shared
        manager.resetToDefaults()

        // October 2026 Default Rates
        XCTAssertEqual(manager.getPrice(for: "Petrol Octane 92"), 414.0)
        XCTAssertEqual(manager.getPrice(for: "Petrol Octane 95 (Premium)"), 450.0)
        XCTAssertEqual(manager.getPrice(for: "Petrol Octane 95 (Euro 4)"), 440.0)
        XCTAssertEqual(manager.getPrice(for: "Petrol XtraPremium Euro 3"), 445.0)
        XCTAssertEqual(manager.getPrice(for: "Lanka Auto Diesel"), 392.0)
        XCTAssertEqual(manager.getPrice(for: "Lanka Super Diesel 4 Star (Euro 4)"), 435.0)

        // Fuzzy matches
        XCTAssertEqual(manager.getPrice(for: "petrol 92"), 414.0)
        XCTAssertEqual(manager.getPrice(for: "auto diesel"), 392.0)
        XCTAssertEqual(manager.getPrice(for: "super diesel"), 435.0)

        // Price Update Test
        manager.updatePrice(for: "Petrol Octane 92", price: 420.0)
        XCTAssertEqual(manager.getPrice(for: "Petrol Octane 92"), 420.0)
        manager.resetToDefaults()
    }

    // MARK: - Legacy Full-Tank Logic Tests
    func testFullTankFuelEconomyWithConsecutiveFills() throws {
        let date1 = Date().addingTimeInterval(-86400 * 5)
        let date2 = Date().addingTimeInterval(-86400 * 2)
        
        let e1 = FuelEntry(date: date1, odometer: 10000.0, volume: 30.0, totalCost: Decimal(12000), isFullTank: true)
        let e2 = FuelEntry(date: date2, odometer: 10450.0, volume: 30.0, totalCost: Decimal(12000), isFullTank: true)
        
        let intervals = FuelStatistics.computeFullTankIntervals(from: [e1, e2])
        
        // 450 km / 30 L = 15.0 km/L
        XCTAssertEqual(intervals.count, 1)
        XCTAssertEqual(intervals.first?.distance, 450.0)
        XCTAssertEqual(intervals.first?.consumedVolume, 30.0)
        XCTAssertEqual(intervals.first?.economy, 15.0)
    }

    func testFullTankFuelEconomyWithInterveningPartialFills() throws {
        let baseDate = Date()
        // Entry 1: Full tank at 10,000 km
        let e1 = FuelEntry(date: baseDate.addingTimeInterval(-86400 * 10), odometer: 10000.0, volume: 35.0, totalCost: Decimal(14000), isFullTank: true)
        // Entry 2: Partial top-up at 10,200 km (10 L)
        let e2 = FuelEntry(date: baseDate.addingTimeInterval(-86400 * 7), odometer: 10200.0, volume: 10.0, totalCost: Decimal(4000), isFullTank: false)
        // Entry 3: Partial top-up at 10,400 km (15 L)
        let e3 = FuelEntry(date: baseDate.addingTimeInterval(-86400 * 4), odometer: 10400.0, volume: 15.0, totalCost: Decimal(6000), isFullTank: false)
        // Entry 4: Full tank at 10,650 km (15 L)
        let e4 = FuelEntry(date: baseDate.addingTimeInterval(-86400 * 1), odometer: 10650.0, volume: 15.0, totalCost: Decimal(6000), isFullTank: true)
        
        let intervals = FuelStatistics.computeFullTankIntervals(from: [e1, e2, e3, e4])
        
        // Distance between e1 and e4: 10,650 - 10,000 = 650 km
        // Consumed volume: e2 (10) + e3 (15) + e4 (15) = 40 L
        // Economy: 650 / 40 = 16.25 km/L
        XCTAssertEqual(intervals.count, 1)
        let interval = try XCTUnwrap(intervals.first)
        XCTAssertEqual(interval.distance, 650.0)
        XCTAssertEqual(interval.consumedVolume, 40.0)
        XCTAssertEqual(interval.economy, 16.25, accuracy: 0.001)
    }

    func testFullTankFuelEconomyInsufficientDataWhenFewerThanTwoFullFills() {
        let baseDate = Date()
        // Case A: 0 full tanks (all partial)
        let p1 = FuelEntry(date: baseDate.addingTimeInterval(-86400 * 5), odometer: 10000.0, volume: 15.0, totalCost: Decimal(6000), isFullTank: false)
        let p2 = FuelEntry(date: baseDate.addingTimeInterval(-86400 * 2), odometer: 10250.0, volume: 15.0, totalCost: Decimal(6000), isFullTank: false)
        let intervals0 = FuelStatistics.computeFullTankIntervals(from: [p1, p2])
        XCTAssertTrue(intervals0.isEmpty)
        
        let benchmark0 = FuelStatistics.benchmark(actualEconomy: (nil as Double?), cityTarget: 10.0, highwayTarget: 15.0)
        XCTAssertEqual(benchmark0.status, .insufficientData)
        XCTAssertEqual(benchmark0.status.rawValue, "Not enough data")
        
        // Case B: Only 1 full tank
        let f1 = FuelEntry(date: baseDate.addingTimeInterval(-86400 * 1), odometer: 10500.0, volume: 30.0, totalCost: Decimal(12000), isFullTank: true)
        let intervals1 = FuelStatistics.computeFullTankIntervals(from: [p1, p2, f1])
        XCTAssertTrue(intervals1.isEmpty)
        
        let benchmark1 = FuelStatistics.benchmark(actualEconomy: (nil as Double?), cityTarget: 10.0, highwayTarget: 15.0)
        XCTAssertEqual(benchmark1.status, .insufficientData)
    }

    func testTrailingPartialFillDoesNotCorruptCompletedInterval() throws {
        let baseDate = Date()
        let e1 = FuelEntry(date: baseDate.addingTimeInterval(-86400 * 8), odometer: 20000.0, volume: 30.0, totalCost: Decimal(12000), isFullTank: true)
        let e2 = FuelEntry(date: baseDate.addingTimeInterval(-86400 * 4), odometer: 20400.0, volume: 25.0, totalCost: Decimal(10000), isFullTank: true)
        // Trailing partial fill
        let e3 = FuelEntry(date: baseDate.addingTimeInterval(-86400 * 1), odometer: 20550.0, volume: 10.0, totalCost: Decimal(4000), isFullTank: false)
        
        let intervals = FuelStatistics.computeFullTankIntervals(from: [e1, e2, e3])
        
        // Interval completed between e1 and e2: 400 km / 25 L = 16.0 km/L
        XCTAssertEqual(intervals.count, 1)
        XCTAssertEqual(intervals.first?.economy, 16.0)
    }

    // MARK: - Fuel Level Tracking Mode: Feature Tests
    
    // 1. Interval economy with known example
    // Tank 40 L: fill to full at 10,000 km; at 10,400 km level before = 25% and refill of 25 L (not full); at 10,800 km level before = 20%.
    func testIntervalEconomyKnownExample() throws {
        let tankCapacity = 40.0
        let baseDate = Date()
        
        // Log 1: fill to full at 10,000 km -> levelAfter = 1.0 (40 L)
        let e1 = FuelEntry(
            date: baseDate.addingTimeInterval(-86400 * 6),
            odometer: 10000.0,
            volume: 40.0,
            totalCost: Decimal(16000),
            isFullTank: true,
            fuelLevelBefore: 0.10
        )
        
        // Log 2: at 10,400 km, level before = 25% (0.25), refill of 25 L (not full)
        // Fuel used for Interval 1 = (levelAfter(A) - levelBefore(B)) * tankCapacity
        //                          = (1.0 - 0.25) * 40.0 = 0.75 * 40.0 = 30.0 L
        // Distance = 10,400 - 10,000 = 400.0 km
        // Economy = 400.0 / 30.0 = 13.3333... km/L
        // Level after refuel 2 = min(1.0, 0.25 + 25.0 / 40.0) = min(1.0, 0.25 + 0.625) = 0.875 (35.0 L)
        let e2 = FuelEntry(
            date: baseDate.addingTimeInterval(-86400 * 3),
            odometer: 10400.0,
            volume: 25.0,
            totalCost: Decimal(10000),
            isFullTank: false,
            fuelLevelBefore: 0.25
        )
        
        // Log 3: at 10,800 km, level before = 20% (0.20)
        // Fuel used for Interval 2 = (levelAfter(B) - levelBefore(C)) * tankCapacity
        //                          = (0.875 - 0.20) * 40.0 = 0.675 * 40.0 = 27.0 L
        // Distance = 10,800 - 10,400 = 400.0 km
        // Economy = 400.0 / 27.0 = 14.8148... km/L
        let e3 = FuelEntry(
            date: baseDate,
            odometer: 10800.0,
            volume: 20.0,
            totalCost: Decimal(8000),
            isFullTank: false,
            fuelLevelBefore: 0.20
        )
        
        let stats = FuelStatistics.compute(
            entries: [e1, e2, e3],
            tankCapacity: tankCapacity,
            trackingMode: .levelTracked
        )
        
        XCTAssertEqual(stats.intervals.count, 2)
        
        // Verify Interval 1
        let interval1 = stats.intervals[0]
        XCTAssertEqual(interval1.distance, 400.0)
        XCTAssertEqual(interval1.consumedVolume, 30.0, accuracy: 0.0001)
        XCTAssertEqual(interval1.economy, 400.0 / 30.0, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(interval1.fuelLevelBeforeA), 0.10, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(interval1.fuelLevelAfterA), 1.0, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(interval1.fuelLevelBeforeB), 0.25, accuracy: 0.0001)
        
        // Verify Interval 2
        let interval2 = stats.intervals[1]
        XCTAssertEqual(interval2.distance, 400.0)
        XCTAssertEqual(interval2.consumedVolume, 27.0, accuracy: 0.0001)
        XCTAssertEqual(interval2.economy, 400.0 / 27.0, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(interval2.fuelLevelBeforeA), 0.25, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(interval2.fuelLevelAfterA), 0.875, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(interval2.fuelLevelBeforeB), 0.20, accuracy: 0.0001)
        
        // Verify rolling average of the 2 valid intervals
        let expectedRollingAvg = ((400.0 / 30.0) + (400.0 / 27.0)) / 2.0
        XCTAssertEqual(stats.rollingIntervalCount, 2)
        let actualRollingAvg = try XCTUnwrap(stats.rollingAverageEconomy)
        XCTAssertEqual(actualRollingAvg, expectedRollingAvg, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(stats.averageEconomy), actualRollingAvg, accuracy: 0.0001)
    }

    // 2. Missing level values, zero/negative fuel used, and zero distance are skipped without crashing
    func testMissingLevelValuesZeroNegativeFuelUsedAndZeroDistanceSkipped() {
        let tank = 40.0
        let baseDate = Date()
        
        // Log 1: valid level
        let e1 = FuelEntry(date: baseDate.addingTimeInterval(-86400 * 10), odometer: 10000.0, volume: 20.0, totalCost: Decimal(8000), isFullTank: true, fuelLevelBefore: 0.5)
        // Log 2: missing level -> interval e1 -> e2 skipped, e2 -> e3 skipped
        let e2 = FuelEntry(date: baseDate.addingTimeInterval(-86400 * 8), odometer: 10300.0, volume: 20.0, totalCost: Decimal(8000), isFullTank: false, fuelLevelBefore: nil)
        // Log 3: valid level, but 0 distance to next entry
        let e3 = FuelEntry(date: baseDate.addingTimeInterval(-86400 * 6), odometer: 10500.0, volume: 15.0, totalCost: Decimal(6000), isFullTank: false, fuelLevelBefore: 0.4)
        // Log 4: same odometer as e3 (0 distance) -> skipped
        let e4 = FuelEntry(date: baseDate.addingTimeInterval(-86400 * 4), odometer: 10500.0, volume: 10.0, totalCost: Decimal(4000), isFullTank: false, fuelLevelBefore: 0.3)
        // Log 5: negative fuel used (levelBefore of next is greater than levelAfter of previous)
        // levelAfter e4 = min(1.0, 0.3 + 10/40) = 0.55. Next log has levelBefore = 0.80 -> fuelUsed = (0.55 - 0.80) * 40 = -10 L -> skipped
        let e5 = FuelEntry(date: baseDate.addingTimeInterval(-86400 * 2), odometer: 10700.0, volume: 10.0, totalCost: Decimal(4000), isFullTank: false, fuelLevelBefore: 0.80)
        
        let stats = FuelStatistics.compute(entries: [e1, e2, e3, e4, e5], tankCapacity: tank, trackingMode: .levelTracked)
        
        // All problematic intervals are skipped without crashing or dividing by zero
        XCTAssertTrue(stats.intervals.isEmpty)
        XCTAssertNil(stats.averageEconomy)
        XCTAssertNil(stats.rollingAverageEconomy)
        XCTAssertEqual(stats.rollingIntervalCount, 0)
    }

    // 3. Level after refuel is capped at 100%
    func testLevelAfterRefuelCappedAt100Percent() throws {
        let tank = 40.0
        let baseDate = Date()
        
        // Log 1: level before = 80%, refill = 20 L (which is 50% of 40 L). 80% + 50% = 130%.
        // levelAfter MUST be capped at 1.0 (100%).
        let e1 = FuelEntry(
            date: baseDate.addingTimeInterval(-86400 * 2),
            odometer: 20000.0,
            volume: 20.0,
            totalCost: Decimal(8000),
            isFullTank: false,
            fuelLevelBefore: 0.80
        )
        
        // Log 2: odometer = 20300.0 (300 km), level before = 50% (0.50).
        // If capped at 1.0, fuelUsed = (1.0 - 0.50) * 40.0 = 20.0 L.
        // (If not capped, it would be (1.30 - 0.50) * 40 = 32.0 L).
        let e2 = FuelEntry(
            date: baseDate,
            odometer: 20300.0,
            volume: 10.0,
            totalCost: Decimal(4000),
            isFullTank: false,
            fuelLevelBefore: 0.50
        )
        
        let stats = FuelStatistics.compute(entries: [e1, e2], tankCapacity: tank, trackingMode: .levelTracked)
        XCTAssertEqual(stats.intervals.count, 1)
        let interval = try XCTUnwrap(stats.intervals.first)
        XCTAssertEqual(try XCTUnwrap(interval.fuelLevelAfterA), 1.0, accuracy: 0.0001)
        XCTAssertEqual(interval.consumedVolume, 20.0, accuracy: 0.0001)
        XCTAssertEqual(interval.distance, 300.0)
        XCTAssertEqual(interval.economy, 15.0, accuracy: 0.0001) // 300 / 20 = 15.0 km/L
    }

    // 4. Rolling average uses only the last 3-5 valid intervals
    func testRollingAverageUsesOnlyLast3To5ValidIntervals() {
        let tank = 50.0
        let baseDate = Date()
        var entries: [FuelEntry] = []
        
        // Generate 7 entries -> 6 intervals
        let distances = [300.0, 320.0, 360.0, 400.0, 440.0, 480.0]
        var currentOdo = 50000.0
        
        entries.append(FuelEntry(
            date: baseDate.addingTimeInterval(-86400 * 20),
            odometer: currentOdo,
            volume: 40.0,
            totalCost: Decimal(16000),
            isFullTank: true,
            fuelLevelBefore: 0.20
        ))
        
        for (index, dist) in distances.enumerated() {
            currentOdo += dist
            entries.append(FuelEntry(
                date: baseDate.addingTimeInterval(Double(-86400 * (18 - index * 3))),
                odometer: currentOdo,
                volume: 40.0,
                totalCost: Decimal(16000),
                isFullTank: true,
                fuelLevelBefore: 0.20
            ))
        }
        
        let stats = FuelStatistics.compute(entries: entries, tankCapacity: tank, trackingMode: .levelTracked)
        XCTAssertEqual(stats.intervals.count, 6)
        
        // Rolling average must only use the last 5 intervals (Intervals 2 through 6)
        XCTAssertEqual(stats.rollingIntervalCount, 5)
        let last5Economies = [8.0, 9.0, 10.0, 11.0, 12.0]
        let expectedRollingAvg = last5Economies.reduce(0.0, +) / 5.0 // (8+9+10+11+12)/5 = 10.0
        XCTAssertEqual(stats.rollingAverageEconomy ?? 0, expectedRollingAvg, accuracy: 0.0001)
    }

    // 5. .expensesOnly vehicles return no economy values
    func testExpensesOnlyVehicleReturnsNoEconomy() {
        let baseDate = Date()
        let e1 = FuelEntry(date: baseDate.addingTimeInterval(-86400 * 3), odometer: 10000.0, volume: 30.0, totalCost: Decimal(12000), isFullTank: true, fuelLevelBefore: 0.5)
        let e2 = FuelEntry(date: baseDate, odometer: 10400.0, volume: 30.0, totalCost: Decimal(12000), isFullTank: true, fuelLevelBefore: 0.2)
        
        let stats = FuelStatistics.compute(
            entries: [e1, e2],
            tankCapacity: 45.0,
            trackingMode: .expensesOnly
        )
        
        XCTAssertNil(stats.averageEconomy)
        XCTAssertNil(stats.rollingAverageEconomy)
        XCTAssertEqual(stats.rollingIntervalCount, 0)
        XCTAssertTrue(stats.intervals.isEmpty)
        XCTAssertNil(stats.bestEconomy)
        XCTAssertNil(stats.worstEconomy)
        
        // Financial & distance stats must still be calculated
        XCTAssertEqual(stats.totalSpent, Decimal(24000))
        XCTAssertEqual(stats.totalDistance, 400.0)
        XCTAssertNotNil(stats.costPerKm)
        XCTAssertNotNil(stats.averageFuelPrice)
    }

    // 6. Programmatic store migration V1 to V2
    func testProgrammaticStoreMigrationV1ToV2() throws {
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        let storeURL = tempDir.appendingPathComponent("v1_legacy_store.sqlite")
        
        // Step A: Create store using V1 Model
        let v1Model = PersistenceController.createV1Model()
        let v1Coordinator = NSPersistentStoreCoordinator(managedObjectModel: v1Model)
        let v1Store = try v1Coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: storeURL,
            options: nil
        )
        
        let v1Context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        v1Context.persistentStoreCoordinator = v1Coordinator
        
        // Insert V1 Vehicle
        let vehicleEntity = NSEntityDescription.entity(forEntityName: "Vehicle", in: v1Context)!
        let v1Vehicle = NSManagedObject(entity: vehicleEntity, insertInto: v1Context)
        v1Vehicle.setValue(UUID(), forKey: "id")
        v1Vehicle.setValue("Legacy Corolla", forKey: "name")
        v1Vehicle.setValue("WP CA-1234", forKey: "plateNumber")
        v1Vehicle.setValue("Car", forKey: "vehicleType")
        v1Vehicle.setValue(Double(50.0), forKey: "tankCapacity")
        v1Vehicle.setValue(Double(10000.0), forKey: "initialOdometer")
        v1Vehicle.setValue(Double(14.0), forKey: "cityFuelConsumption")
        v1Vehicle.setValue(Double(18.0), forKey: "highwayFuelConsumption")
        
        // Insert V1 FuelLog (without fuelLevelBefore or isExcludedFromConsumption)
        let logEntity = NSEntityDescription.entity(forEntityName: "FuelLog", in: v1Context)!
        let v1Log = NSManagedObject(entity: logEntity, insertInto: v1Context)
        v1Log.setValue(UUID(), forKey: "id")
        v1Log.setValue(Date(), forKey: "date")
        v1Log.setValue(Double(10400.0), forKey: "odometer")
        v1Log.setValue(Double(30.0), forKey: "volume")
        v1Log.setValue(NSDecimalNumber(value: 9000), forKey: "totalCost")
        v1Log.setValue("Ceypetco", forKey: "stationName")
        v1Log.setValue("Petrol 92", forKey: "fuelGrade")
        v1Log.setValue("City", forKey: "tripType")
        v1Log.setValue(true, forKey: "isFullTank")
        v1Log.setValue(v1Vehicle, forKey: "vehicle")
        
        try v1Context.save()
        
        // Detach store from coordinator so SQLite locks are released
        try v1Coordinator.remove(v1Store)
        
        // Step B: Run programmatic migration
        PersistenceController.migrateStoreIfNeeded(at: storeURL)
        
        // Step C: Open with V2 Model
        let v2Model = PersistenceController.createModel()
        let v2Coordinator = NSPersistentStoreCoordinator(managedObjectModel: v2Model)
        let _ = try v2Coordinator.addPersistentStore(
            ofType: NSSQLiteStoreType,
            configurationName: nil,
            at: storeURL,
            options: nil
        )
        let v2Context = NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        v2Context.persistentStoreCoordinator = v2Coordinator
        
        let vehicleFetch = NSFetchRequest<Vehicle>(entityName: "Vehicle")
        let vehicles = try v2Context.fetch(vehicleFetch)
        XCTAssertEqual(vehicles.count, 1)
        let migratedVehicle = vehicles[0]
        XCTAssertEqual(migratedVehicle.name, "Legacy Corolla")
        
        // Defaults to .levelTracked
        XCTAssertEqual(migratedVehicle.trackingMode, .levelTracked)
        XCTAssertEqual(migratedVehicle.effectiveTankCapacity, 50.0)
        
        // Old logs lack fuelLevelBefore and are excluded from consumption without crashing
        let logFetch = NSFetchRequest<FuelLog>(entityName: "FuelLog")
        let logs = try v2Context.fetch(logFetch)
        XCTAssertEqual(logs.count, 1)
        let migratedLog = logs[0]
        XCTAssertNil(migratedLog.fuelLevelBefore)
        XCTAssertFalse(migratedLog.isExcluded)
        
        let stats = FuelStatistics.compute(
            entries: logs.map { $0.toFuelEntry() },
            tankCapacity: migratedVehicle.effectiveTankCapacity,
            trackingMode: migratedVehicle.trackingMode
        )
        XCTAssertNil(stats.averageEconomy)
        XCTAssertTrue(stats.intervals.isEmpty)
    }

    // 7. Switching a vehicle's mode back and forth preserves all logs
    func testSwitchingTrackingModePreservesAllLogs() throws {
        let vehicle = Vehicle(context: context)
        vehicle.id = UUID()
        vehicle.name = "Test Switcher"
        vehicle.plateNumber = "CAB-9999"
        vehicle.vehicleType = "Car"
        vehicle.fuelTrackingMode = FuelTrackingMode.levelTracked.rawValue
        vehicle.tankCapacityLiters = 40.0
        vehicle.tankCapacity = 40.0
        vehicle.initialOdometer = 10000.0
        vehicle.cityFuelConsumption = 15.0
        vehicle.highwayFuelConsumption = 18.0
        
        // Add 3 logs
        let log1 = FuelLog(context: context)
        log1.id = UUID()
        log1.date = Date().addingTimeInterval(-86400 * 4)
        log1.odometer = 10000.0
        log1.volume = 30.0
        log1.totalCost = NSDecimalNumber(value: 9000)
        log1.isFullTank = true
        log1.remainingFuelPercentBefore = 0.50
        log1.vehicle = vehicle
        
        let log2 = FuelLog(context: context)
        log2.id = UUID()
        log2.date = Date().addingTimeInterval(-86400 * 2)
        log2.odometer = 10400.0
        log2.volume = 20.0
        log2.totalCost = NSDecimalNumber(value: 6000)
        log2.isFullTank = false
        log2.remainingFuelPercentBefore = 0.25
        log2.vehicle = vehicle
        
        let log3 = FuelLog(context: context)
        log3.id = UUID()
        log3.date = Date()
        log3.odometer = 10800.0
        log3.volume = 20.0
        log3.totalCost = NSDecimalNumber(value: 6000)
        log3.isFullTank = false
        log3.remainingFuelPercentBefore = 0.20
        log3.vehicle = vehicle
        
        try context.save()
        XCTAssertEqual(vehicle.fuelLogs.count, 3)
        
        // Step 1: Initial levelTracked computation
        let stats1 = FuelStatistics.compute(
            entries: vehicle.fuelLogs.map { $0.toFuelEntry() },
            tankCapacity: vehicle.effectiveTankCapacity,
            trackingMode: vehicle.trackingMode
        )
        XCTAssertEqual(stats1.intervals.count, 2)
        XCTAssertNotNil(stats1.averageEconomy)
        
        // Step 2: Switch to expensesOnly
        vehicle.fuelTrackingMode = FuelTrackingMode.expensesOnly.rawValue
        try context.save()
        
        // Logs are fully preserved!
        XCTAssertEqual(vehicle.fuelLogs.count, 3)
        let statsExpenses = FuelStatistics.compute(
            entries: vehicle.fuelLogs.map { $0.toFuelEntry() },
            tankCapacity: vehicle.effectiveTankCapacity,
            trackingMode: vehicle.trackingMode
        )
        XCTAssertNil(statsExpenses.averageEconomy)
        XCTAssertTrue(statsExpenses.intervals.isEmpty)
        XCTAssertEqual(statsExpenses.totalDistance, 800.0)
        
        // Step 3: Switch back to levelTracked
        vehicle.fuelTrackingMode = FuelTrackingMode.levelTracked.rawValue
        try context.save()
        
        // Logs are still fully preserved and economy is restored
        XCTAssertEqual(vehicle.fuelLogs.count, 3)
        let statsRestored = FuelStatistics.compute(
            entries: vehicle.fuelLogs.map { $0.toFuelEntry() },
            tankCapacity: vehicle.effectiveTankCapacity,
            trackingMode: vehicle.trackingMode
        )
        XCTAssertEqual(statsRestored.intervals.count, 2)
        XCTAssertNotNil(statsRestored.averageEconomy)
        XCTAssertEqual(statsRestored.averageEconomy, stats1.averageEconomy)
    }

    // 8. CSV export respects tracking mode
    func testCSVExportRespectsTrackingMode() throws {
        let levelVehicle = Vehicle(context: context)
        levelVehicle.id = UUID()
        levelVehicle.name = "Level Car"
        levelVehicle.plateNumber = "LEV-123"
        levelVehicle.fuelTrackingMode = FuelTrackingMode.levelTracked.rawValue
        levelVehicle.tankCapacityLiters = 45.0
        
        let levelLog = FuelLog(context: context)
        levelLog.id = UUID()
        levelLog.date = Date()
        levelLog.odometer = 12000.0
        levelLog.volume = 25.0
        levelLog.totalCost = NSDecimalNumber(value: 8000)
        levelLog.remainingFuelPercentBefore = 0.35
        levelLog.vehicle = levelVehicle
        
        let expensesVehicle = Vehicle(context: context)
        expensesVehicle.id = UUID()
        expensesVehicle.name = "Expenses Car"
        expensesVehicle.plateNumber = "EXP-456"
        expensesVehicle.fuelTrackingMode = FuelTrackingMode.expensesOnly.rawValue
        
        let expensesLog = FuelLog(context: context)
        expensesLog.id = UUID()
        expensesLog.date = Date()
        expensesLog.odometer = 15000.0
        expensesLog.volume = 20.0
        expensesLog.totalCost = NSDecimalNumber(value: 6500)
        expensesLog.vehicle = expensesVehicle
        
        try context.save()
        
        let csvLevel = UnitSettings.shared.exportCSV(logs: [levelLog], vehicleName: levelVehicle.name)
        XCTAssertTrue(csvLevel.contains("fuel_level_before_percent"))
        XCTAssertTrue(csvLevel.contains("35.0%"))
        
        let csvExpenses = UnitSettings.shared.exportCSV(logs: [expensesLog], vehicleName: expensesVehicle.name)
        XCTAssertTrue(csvExpenses.contains("fuel_level_before_percent"))
        // For expenses only, fuel level value must be blank
        XCTAssertFalse(csvExpenses.contains("%\n") || csvExpenses.contains("%,") || csvExpenses.contains("%\r"))
    }

    // 9. Implausible interval flagging and exclusion
    func testImplausibleIntervalFlaggingAndExclusion() throws {
        let tank = 40.0
        let baseDate = Date()
        
        // Log 1: Baseline target = 15 km/L.
        let e1 = FuelEntry(date: baseDate.addingTimeInterval(-86400 * 4), odometer: 10000.0, volume: 40.0, totalCost: Decimal(16000), isFullTank: true, fuelLevelBefore: 0.10)
        
        // Log 2: Distance = 400 km, fuel used = (1.0 - 0.75) * 40 = 10 L -> Economy = 40 km/L.
        // Baseline is 15.0 km/L. Deviation = |40 - 15| / 15 = 166% (> 40%), so it is flagged as implausible.
        let e2 = FuelEntry(date: baseDate.addingTimeInterval(-86400 * 2), odometer: 10400.0, volume: 20.0, totalCost: Decimal(8000), isFullTank: false, fuelLevelBefore: 0.75, isExcluded: false)
        
        let stats = FuelStatistics.compute(entries: [e1, e2], cityTarget: 15.0, highwayTarget: 15.0, tankCapacity: tank, trackingMode: .levelTracked)
        XCTAssertEqual(stats.intervals.count, 1)
        XCTAssertTrue(stats.intervals[0].isImplausible)
        
        // Now test if interval is excluded
        let e2Excluded = FuelEntry(date: baseDate.addingTimeInterval(-86400 * 2), odometer: 10400.0, volume: 20.0, totalCost: Decimal(8000), isFullTank: false, fuelLevelBefore: 0.75, isExcluded: true)
        let statsExcluded = FuelStatistics.compute(entries: [e1, e2Excluded], cityTarget: 15.0, highwayTarget: 15.0, tankCapacity: tank, trackingMode: .levelTracked)
        XCTAssertEqual(statsExcluded.intervals.count, 1)
        XCTAssertTrue(statsExcluded.intervals[0].isExcluded)
        // Since it's excluded, valid intervals are empty, so rollingAverageEconomy is nil
        XCTAssertNil(statsExcluded.rollingAverageEconomy)
        XCTAssertEqual(statsExcluded.rollingIntervalCount, 0)
    }

    // MARK: - Phase 1: Pure Benchmarking Tests
    func testBenchmarkingTargets() {
        let city = 10.0
        let hwy = 16.0
        
        // Above Highway
        let resAbove = FuelStatistics.benchmark(actualEconomy: 17.5, cityTarget: city, highwayTarget: hwy)
        XCTAssertEqual(resAbove.status, .aboveHighway)
        XCTAssertGreaterThan(resAbove.percentageDelta, 0)
        
        // On Target (between City and Highway)
        let resOn = FuelStatistics.benchmark(actualEconomy: 13.0, cityTarget: city, highwayTarget: hwy)
        XCTAssertEqual(resOn.status, .onTarget)
        
        // Below City
        let resBelow = FuelStatistics.benchmark(actualEconomy: 8.5, cityTarget: city, highwayTarget: hwy)
        XCTAssertEqual(resBelow.status, .belowCity)
        XCTAssertLessThan(resBelow.percentageDelta, 0)
    }

    // MARK: - Phase 1: Decimal Exactness & Money Rounding Tests
    func testDecimalPrecisionAndCostPerKm() throws {
        let cost1 = Decimal(string: "6220.50")!
        let cost2 = Decimal(string: "3779.50")!
        let totalCost = cost1 + cost2
        XCTAssertEqual(totalCost, Decimal(10000.00))
        
        let e1 = FuelEntry(odometer: 50000.0, volume: 20.0, totalCost: cost1, isFullTank: true)
        let e2 = FuelEntry(odometer: 50500.0, volume: 15.0, totalCost: cost2, isFullTank: true)
        
        let stats = FuelStatistics.compute(entries: [e1, e2])
        XCTAssertEqual(stats.totalSpent, Decimal(10000.00))
        XCTAssertEqual(stats.totalDistance, 500.0)
        
        // Cost per km: 10,000 / 500 = 20.00
        XCTAssertEqual(stats.costPerKm, Decimal(20.00))
        
        // Average Price: 10,000 / 35 = 285.714...
        let avgPrice = try XCTUnwrap(stats.averageFuelPrice)
        let doublePrice = NSDecimalNumber(decimal: avgPrice).doubleValue
        XCTAssertEqual(doublePrice, 10000.0 / 35.0, accuracy: 0.01)
    }

    // MARK: - Phase 1: Data Sanity Warnings Tests
    func testDataSanityWarningsTriggering() {
        // 1. Tank capacity exceeded
        let warnings1 = FuelStatistics.validateSanity(
            enteredVolume: 55.0,
            tankCapacity: 45.0,
            enteredOdometer: 10500.0,
            previousOdometer: 10000.0,
            baselineEconomy: 15.0,
            estimatedEconomy: 14.5
        )
        XCTAssertTrue(warnings1.contains { $0.type == .volumeExceedsTank })
        
        // 2. Odometer jump threshold (> 1500 km)
        let warnings2 = FuelStatistics.validateSanity(
            enteredVolume: 40.0,
            tankCapacity: 45.0,
            enteredOdometer: 12000.0,
            previousOdometer: 10000.0, // jump of 2,000 km
            baselineEconomy: 15.0,
            estimatedEconomy: 15.0
        )
        XCTAssertTrue(warnings2.contains { $0.type == .odometerJump })
        
        // 3. Economy > 40% away from baseline
        let warnings3 = FuelStatistics.validateSanity(
            enteredVolume: 40.0,
            tankCapacity: 45.0,
            enteredOdometer: 10500.0,
            previousOdometer: 10000.0, // 500 km / 40 L = 12.5 km/L
            baselineEconomy: 22.0, // (22 - 12.5) / 22 = 43.1% deviation
            estimatedEconomy: 12.5
        )
        XCTAssertTrue(warnings3.contains { $0.type == .economyDeviation })
        
        // 4. Normal fill produces no warnings
        let normalWarnings = FuelStatistics.validateSanity(
            enteredVolume: 35.0,
            tankCapacity: 45.0,
            enteredOdometer: 10500.0,
            previousOdometer: 10000.0,
            baselineEconomy: 15.0,
            estimatedEconomy: 14.28
        )
        XCTAssertTrue(normalWarnings.isEmpty)
    }

    // MARK: - ViewModel & Multi-Vehicle Management Tests
    @MainActor
    func testMultiVehicleManagement() throws {
        let viewModel = FuelLogViewModel(context: context)
        
        let initialCount = viewModel.vehicles.count
        let wagonR = viewModel.addVehicle(
            name: "Suzuki Wagon R",
            plateNumber: "WP CAD-7890",
            vehicleType: "Car",
            tankCapacity: 35.0,
            initialOdometer: 28000.0,
            cityFuelConsumption: 14.0,
            highwayFuelConsumption: 18.0
        )
        
        XCTAssertEqual(viewModel.vehicles.count, initialCount + 1)
        XCTAssertEqual(viewModel.selectedVehicle?.name, "Suzuki Wagon R")
        XCTAssertEqual(wagonR.effectiveCityConsumption, 14.0)
        XCTAssertEqual(wagonR.effectiveHighwayConsumption, 18.0)
        
        // Add log with Trip Type to Wagon R
        try viewModel.addLog(
            odometer: 28350.0,
            volume: 15.0,
            totalCost: 4665.0,
            stationName: "Lanka IOC",
            fuelGrade: "Petrol Octane 92",
            tripType: "Highway"
        )
        
        XCTAssertEqual(viewModel.logs.count, 1)
        XCTAssertEqual(viewModel.logs.first?.tripType, "Highway")
        XCTAssertEqual(viewModel.totalSpent, 4665.0)
        XCTAssertEqual(viewModel.totalDistance, 350.0) // 28350 - 28000
    }

    // MARK: - Strict Validations
    @MainActor
    func testOdometerRegressionThrowsError() throws {
        let viewModel = FuelLogViewModel(context: context)
        viewModel.addVehicle(
            name: "Toyota Prius",
            plateNumber: "WP CAB-2045",
            vehicleType: "Car",
            tankCapacity: 45.0,
            initialOdometer: 45000.0,
            cityFuelConsumption: 18.0,
            highwayFuelConsumption: 22.0
        )
        
        // First log
        try viewModel.addLog(
            odometer: 45500.0,
            volume: 20.0,
            totalCost: 6220.0,
            stationName: "Ceypetco",
            tripType: "City"
        )
        
        // Attempting to add an entry with odometer lower than or equal to previous must throw
        XCTAssertThrowsError(try viewModel.addLog(
            odometer: 45400.0,
            volume: 15.0,
            totalCost: 4600.0,
            stationName: "Lanka IOC",
            tripType: "Highway"
        )) { error in
            guard let validationError = error as? FuelLogValidationError else {
                XCTFail("Expected FuelLogValidationError but got \(error)")
                return
            }
            if case .odometerRegression(let entered, let previous) = validationError {
                XCTAssertEqual(entered, 45400.0)
                XCTAssertEqual(previous, 45500.0)
            } else {
                XCTFail("Expected odometerRegression error")
            }
        }
    }

    @MainActor
    func testNegativeOrZeroMetricsThrowError() throws {
        let viewModel = FuelLogViewModel(context: context)
        viewModel.addVehicle(
            name: "Toyota Prius",
            plateNumber: "WP CAB-2045",
            vehicleType: "Car",
            tankCapacity: 45.0,
            initialOdometer: 45000.0,
            cityFuelConsumption: 18.0,
            highwayFuelConsumption: 22.0
        )
        
        // Zero odometer
        XCTAssertThrowsError(try viewModel.addLog(
            odometer: 0.0,
            volume: 15.0,
            totalCost: 4600.0,
            stationName: "Sinopec"
        ))
        
        // Zero volume
        XCTAssertThrowsError(try viewModel.addLog(
            odometer: 46000.0,
            volume: 0.0,
            totalCost: 4600.0,
            stationName: "Sinopec"
        ))
        
        // Zero totalCost
        XCTAssertThrowsError(try viewModel.addLog(
            odometer: 46000.0,
            volume: 15.0,
            totalCost: 0.0,
            stationName: "Sinopec"
        ))
    }

    // MARK: - Sri Lankan Demo Data Seeding & Metric Tests
    @MainActor
    func testSeedSriLankanDemoData() throws {
        let viewModel = FuelLogViewModel(context: context)
        viewModel.seedSriLankanDemoData()
        
        XCTAssertGreaterThanOrEqual(viewModel.vehicles.count, 3)
        XCTAssertNotNil(viewModel.selectedVehicle)
        XCTAssertFalse(viewModel.logs.isEmpty)
        XCTAssertGreaterThan(viewModel.totalSpent, 0)
        XCTAssertGreaterThan(viewModel.totalDistance, 0)
        XCTAssertGreaterThan(viewModel.averageEfficiency, 0)
        XCTAssertGreaterThan(viewModel.costPerKm, 0)
        
        // Verify Dual Consumption Targets on Seeded Vehicles
        let prius = viewModel.vehicles.first(where: { $0.name.contains("Prius") })
        XCTAssertNotNil(prius)
        XCTAssertEqual(prius?.cityFuelConsumption, 18.0)
        XCTAssertEqual(prius?.highwayFuelConsumption, 22.0)
        
        // Verify logs have tripType
        for log in viewModel.logs {
            XCTAssertFalse(log.effectiveTripType.isEmpty)
        }
    }

    // MARK: - Station Search Brand Classifier
    func testStationBrandDetection() async {
        let service = StationSearchService()
        let results = await service.searchStations(query: "ceypetco")
        XCTAssertFalse(results.isEmpty)
        XCTAssertEqual(service.detectBrand(from: "Ceypetco Fuel Station"), "Ceypetco")
        XCTAssertEqual(service.detectBrand(from: "Lanka IOC Petrol Shed"), "Lanka IOC")
        XCTAssertEqual(service.detectBrand(from: "Sinopec Filling Station"), "Sinopec")
    }
}
