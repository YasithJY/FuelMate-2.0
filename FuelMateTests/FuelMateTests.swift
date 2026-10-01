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
        log.totalCost = 6220.0
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
