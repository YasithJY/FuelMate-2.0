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

        let log = FuelLog(context: context)
        log.id = UUID()
        log.date = Date()
        log.odometer = 45450.0
        log.volume = 20.0
        log.totalCost = 6220.0
        log.stationName = "Ceypetco"
        log.fuelGrade = "Petrol 92 Octane"
        log.isFullTank = true
        log.vehicle = vehicle

        try context.save()

        XCTAssertEqual(vehicle.fuelLogs.count, 1)
        XCTAssertEqual(vehicle.fuelLogs.first?.stationName, "Ceypetco")
        let price = try XCTUnwrap(vehicle.fuelLogs.first?.unitPrice)
        XCTAssertEqual(price, 311.0, accuracy: 0.1)
        XCTAssertEqual(log.vehicle?.name, "Toyota Prius")
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
            initialOdometer: 28000.0
        )
        
        XCTAssertEqual(viewModel.vehicles.count, initialCount + 1)
        XCTAssertEqual(viewModel.selectedVehicle?.name, "Suzuki Wagon R")
        
        // Add log to Wagon R
        try viewModel.addLog(
            odometer: 28350.0,
            volume: 15.0,
            totalCost: 4665.0,
            stationName: "Lanka IOC",
            fuelGrade: "Petrol 92 Octane"
        )
        
        XCTAssertEqual(viewModel.logs.count, 1)
        XCTAssertEqual(viewModel.totalSpent, 4665.0)
        XCTAssertEqual(viewModel.totalDistance, 350.0) // 28350 - 28000
    }

    // MARK: - Strict Validations
    @MainActor
    func testOdometerRegressionThrowsError() throws {
        let viewModel = FuelLogViewModel(context: context)
        
        // First log
        try viewModel.addLog(
            odometer: 45500.0,
            volume: 20.0,
            totalCost: 6220.0,
            stationName: "Ceypetco"
        )
        
        // Attempting to add an entry with odometer lower than or equal to previous must throw
        XCTAssertThrowsError(try viewModel.addLog(
            odometer: 45400.0,
            volume: 15.0,
            totalCost: 4600.0,
            stationName: "Lanka IOC"
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
    }

    // MARK: - Station Search Brand Classifier
    func testStationBrandDetection() async {
        let service = StationSearchService()
        let results = await service.searchStations(query: "ceypetco")
        XCTAssertFalse(results.isEmpty)
    }
}
