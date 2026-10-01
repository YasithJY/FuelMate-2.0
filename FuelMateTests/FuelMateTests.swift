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

    // MARK: - Phase 1: Pure FuelStatistics & Full-Tank Logic Tests
    func testFullTankFuelEconomyWithConsecutiveFills() throws {
        let date1 = Date().addingTimeInterval(-86400 * 5)
        let date2 = Date().addingTimeInterval(-86400 * 2)
        
        let e1 = FuelEntry(date: date1, odometer: 10000.0, volume: 30.0, totalCost: Decimal(12000), isFullTank: true)
        let e2 = FuelEntry(date: date2, odometer: 10450.0, volume: 30.0, totalCost: Decimal(12000), isFullTank: true)
        
        let stats = FuelStatistics.compute(entries: [e1, e2])
        
        // 450 km / 30 L = 15.0 km/L
        XCTAssertNotNil(stats.averageEconomy)
        XCTAssertEqual(try XCTUnwrap(stats.averageEconomy), 15.0, accuracy: 0.001)
        XCTAssertEqual(stats.intervals.count, 1)
        XCTAssertEqual(stats.intervals.first?.distance, 450.0)
        XCTAssertEqual(stats.intervals.first?.consumedVolume, 30.0)
        XCTAssertEqual(stats.intervals.first?.economy, 15.0)
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
        
        let stats = FuelStatistics.compute(entries: [e1, e2, e3, e4])
        
        // Distance between e1 and e4: 10,650 - 10,000 = 650 km
        // Consumed volume: e2 (10) + e3 (15) + e4 (15) = 40 L
        // Economy: 650 / 40 = 16.25 km/L
        XCTAssertEqual(stats.intervals.count, 1)
        let interval = try XCTUnwrap(stats.intervals.first)
        XCTAssertEqual(interval.distance, 650.0)
        XCTAssertEqual(interval.consumedVolume, 40.0)
        XCTAssertEqual(interval.economy, 16.25, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(stats.averageEconomy), 16.25, accuracy: 0.001)
    }

    func testFullTankFuelEconomyInsufficientDataWhenFewerThanTwoFullFills() {
        let baseDate = Date()
        // Case A: 0 full tanks (all partial)
        let p1 = FuelEntry(date: baseDate.addingTimeInterval(-86400 * 5), odometer: 10000.0, volume: 15.0, totalCost: Decimal(6000), isFullTank: false)
        let p2 = FuelEntry(date: baseDate.addingTimeInterval(-86400 * 2), odometer: 10250.0, volume: 15.0, totalCost: Decimal(6000), isFullTank: false)
        let stats0 = FuelStatistics.compute(entries: [p1, p2])
        XCTAssertNil(stats0.averageEconomy)
        XCTAssertTrue(stats0.intervals.isEmpty)
        
        let benchmark0 = FuelStatistics.benchmark(actualEconomy: stats0.averageEconomy, cityTarget: 10.0, highwayTarget: 15.0)
        XCTAssertEqual(benchmark0.status, .insufficientData)
        XCTAssertEqual(benchmark0.status.rawValue, "Not enough data")
        
        // Case B: Only 1 full tank
        let f1 = FuelEntry(date: baseDate.addingTimeInterval(-86400 * 1), odometer: 10500.0, volume: 30.0, totalCost: Decimal(12000), isFullTank: true)
        let stats1 = FuelStatistics.compute(entries: [p1, p2, f1])
        XCTAssertNil(stats1.averageEconomy)
        XCTAssertTrue(stats1.intervals.isEmpty)
        
        let benchmark1 = FuelStatistics.benchmark(actualEconomy: stats1.averageEconomy, cityTarget: 10.0, highwayTarget: 15.0)
        XCTAssertEqual(benchmark1.status, .insufficientData)
    }

    func testTrailingPartialFillDoesNotCorruptCompletedInterval() throws {
        let baseDate = Date()
        let e1 = FuelEntry(date: baseDate.addingTimeInterval(-86400 * 8), odometer: 20000.0, volume: 30.0, totalCost: Decimal(12000), isFullTank: true)
        let e2 = FuelEntry(date: baseDate.addingTimeInterval(-86400 * 4), odometer: 20400.0, volume: 25.0, totalCost: Decimal(10000), isFullTank: true)
        // Trailing partial fill
        let e3 = FuelEntry(date: baseDate.addingTimeInterval(-86400 * 1), odometer: 20550.0, volume: 10.0, totalCost: Decimal(4000), isFullTank: false)
        
        let stats = FuelStatistics.compute(entries: [e1, e2, e3])
        
        // Interval completed between e1 and e2: 400 km / 25 L = 16.0 km/L
        XCTAssertEqual(stats.intervals.count, 1)
        XCTAssertEqual(stats.intervals.first?.economy, 16.0)
        XCTAssertEqual(try XCTUnwrap(stats.averageEconomy), 16.0, accuracy: 0.001)
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
