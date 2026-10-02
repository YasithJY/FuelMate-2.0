import Foundation
import CoreData
import SwiftUI

// MARK: - Validation Errors
public enum FuelLogValidationError: LocalizedError, Equatable {
    case invalidOdometer
    case invalidVolume
    case invalidTotalCost
    case odometerRegression(entered: Double, previous: Double)
    case noVehicleSelected
    
    public var errorDescription: String? {
        switch self {
        case .invalidOdometer:
            return "Odometer must be a positive number greater than 0."
        case .invalidVolume:
            return "Fuel volume must be greater than 0."
        case .invalidTotalCost:
            return "Total cost must be greater than 0."
        case .odometerRegression(let entered, let previous):
            return "Odometer (\(String(format: "%.1f", entered))) must be higher than the last recorded odometer (\(String(format: "%.1f", previous)))."
        case .noVehicleSelected:
            return "Please create or select a vehicle before adding a fuel log."
        }
    }
}

// MARK: - Data Models for Swift Charts
public struct MonthlySpend: Identifiable {
    public var id: String { month }
    public let month: String
    public let amount: Double
    public let date: Date
}

public struct EfficiencyPoint: Identifiable {
    public let id: UUID
    public let date: Date
    public let efficiency: Double
    public let stationName: String
}

public struct PricePoint: Identifiable {
    public let id: UUID
    public let date: Date
    public let pricePerUnit: Double
    public let stationName: String
}

public struct MonthGroup: Identifiable {
    public var id: String { title }
    public let title: String
    public let totalCost: Decimal
    public let totalVolume: Double
    public let logs: [FuelLog]
    
    public var totalCostDouble: Double {
        NSDecimalNumber(decimal: totalCost).doubleValue
    }
}

public enum AnalyticsTimeRange: String, CaseIterable, Identifiable {
    case month = "30D"
    case sixMonths = "6M"
    case year = "1Y"
    case all = "All"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .month: return "30 Days"
        case .sixMonths: return "6 Months"
        case .year: return "1 Year"
        case .all: return "All Time"
        }
    }
}

// MARK: - Main ViewModel for Multi-Vehicle & Log Management
@MainActor
public final class FuelLogViewModel: ObservableObject {
    @Published public var vehicles: [Vehicle] = []
    @Published public var selectedVehicle: Vehicle?
    @Published public var logs: [FuelLog] = []
    
    private let context: NSManagedObjectContext
    
    public init(context: NSManagedObjectContext = PersistenceController.shared.container.viewContext) {
        self.context = context
        bootstrapData()
    }
    
    // MARK: - Initialization & Bootstrapping
    public func bootstrapData() {
        fetchVehicles()
        if selectedVehicle == nil {
            selectedVehicle = vehicles.first
        }
        fetchLogs()
    }
    
    // MARK: - Vehicle Management
    public func fetchVehicles() {
        let request = NSFetchRequest<Vehicle>(entityName: "Vehicle")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Vehicle.name, ascending: true)]
        do {
            vehicles = try context.fetch(request)
            if let current = selectedVehicle, !vehicles.contains(where: { $0.id == current.id }) {
                selectedVehicle = vehicles.first
            } else if selectedVehicle == nil {
                selectedVehicle = vehicles.first
            }
        } catch {
            print("Failed to fetch vehicles: \(error.localizedDescription)")
            vehicles = []
        }
    }
    
    public func selectVehicle(_ vehicle: Vehicle) {
        selectedVehicle = vehicle
        fetchLogs()
    }
    
    @discardableResult
    public func addVehicle(
        name: String,
        plateNumber: String? = nil,
        vehicleType: String = "Car",
        tankCapacity: Double = 45.0,
        initialOdometer: Double = 0.0,
        cityFuelConsumption: Double = 10.0,
        highwayFuelConsumption: Double = 15.0,
        fuelTrackingMode: FuelTrackingMode = .levelTracked
    ) -> Vehicle {
        let vehicle = Vehicle(context: context)
        vehicle.id = UUID()
        vehicle.name = name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "My Vehicle" : name.trimmingCharacters(in: .whitespacesAndNewlines)
        vehicle.plateNumber = plateNumber?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? plateNumber?.trimmingCharacters(in: .whitespacesAndNewlines) : nil
        vehicle.vehicleType = vehicleType
        vehicle.tankCapacity = max(1.0, tankCapacity)
        vehicle.tankCapacityLiters = NSNumber(value: max(1.0, tankCapacity))
        vehicle.initialOdometer = max(0.0, initialOdometer)
        vehicle.cityFuelConsumption = max(0.1, cityFuelConsumption)
        vehicle.highwayFuelConsumption = max(0.1, highwayFuelConsumption)
        vehicle.trackingMode = fuelTrackingMode
        
        saveContext()
        fetchVehicles()
        selectedVehicle = vehicle
        fetchLogs()
        return vehicle
    }
    
    public func updateVehicle(
        _ vehicle: Vehicle,
        name: String,
        plateNumber: String?,
        vehicleType: String,
        tankCapacity: Double,
        initialOdometer: Double,
        cityFuelConsumption: Double = 10.0,
        highwayFuelConsumption: Double = 15.0,
        fuelTrackingMode: FuelTrackingMode? = nil
    ) {
        vehicle.name = name
        vehicle.plateNumber = plateNumber
        vehicle.vehicleType = vehicleType
        vehicle.tankCapacity = max(1.0, tankCapacity)
        vehicle.tankCapacityLiters = NSNumber(value: max(1.0, tankCapacity))
        vehicle.initialOdometer = max(0.0, initialOdometer)
        vehicle.cityFuelConsumption = max(0.1, cityFuelConsumption)
        vehicle.highwayFuelConsumption = max(0.1, highwayFuelConsumption)
        if let mode = fuelTrackingMode {
            vehicle.trackingMode = mode
        }
        saveContext()
        fetchVehicles()
    }
    
    public func deleteVehicle(_ vehicle: Vehicle) {
        let wasSelected = (selectedVehicle?.id == vehicle.id)
        context.delete(vehicle)
        saveContext()
        fetchVehicles()
        if wasSelected {
            selectedVehicle = vehicles.first
        }
        fetchLogs()
    }
    
    // MARK: - FuelLog Management Filtered by Selected Vehicle
    public func fetchLogs() {
        guard let currentVehicle = selectedVehicle else {
            logs = []
            return
        }
        
        let request = NSFetchRequest<FuelLog>(entityName: "FuelLog")
        request.predicate = NSPredicate(format: "vehicle == %@", currentVehicle)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FuelLog.date, ascending: false)]
        
        do {
            logs = try context.fetch(request)
        } catch {
            print("Failed to fetch logs for vehicle \(currentVehicle.name): \(error.localizedDescription)")
            logs = []
        }
    }
    
    // MARK: - Strict Validation & Saving
    @discardableResult
    public func addLog(
        odometer: Double,
        volume: Double,
        totalCost: Decimal,
        stationName: String,
        latitude: Double = 0.0,
        longitude: Double = 0.0,
        locality: String? = nil,
        fuelGrade: String = "Petrol Octane 92",
        tripType: String = "City",
        notes: String = "",
        isFullTank: Bool = true,
        date: Date = Date(),
        fuelLevelBefore: Double? = nil
    ) throws -> FuelLog {
        guard let currentVehicle = selectedVehicle else {
            throw FuelLogValidationError.noVehicleSelected
        }
        
        // Strict input validations
        guard !odometer.isNaN && !odometer.isInfinite && odometer > 0 else {
            throw FuelLogValidationError.invalidOdometer
        }
        guard !volume.isNaN && !volume.isInfinite && volume > 0 else {
            throw FuelLogValidationError.invalidVolume
        }
        guard totalCost > 0 else {
            throw FuelLogValidationError.invalidTotalCost
        }
        
        // Logical odometer check: Cannot be lower than or equal to the previous entry of that vehicle
        let previousOdo = latestLog?.odometer ?? currentVehicle.initialOdometer
        if previousOdo > 0 && odometer <= previousOdo {
            throw FuelLogValidationError.odometerRegression(entered: odometer, previous: previousOdo)
        }
        
        let newLog = FuelLog(context: context)
        newLog.id = UUID()
        newLog.date = date
        newLog.odometer = odometer
        newLog.volume = volume
        newLog.totalCost = NSDecimalNumber(decimal: totalCost)
        newLog.stationName = stationName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Fuel Station" : stationName.trimmingCharacters(in: .whitespacesAndNewlines)
        newLog.latitude = latitude
        newLog.longitude = longitude
        newLog.locality = locality?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ? locality : nil
        newLog.fuelGrade = fuelGrade
        newLog.tripType = tripType.isEmpty ? "City" : tripType
        newLog.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : notes.trimmingCharacters(in: .whitespacesAndNewlines)
        newLog.isFullTank = isFullTank
        newLog.fuelLevelBefore = fuelLevelBefore
        newLog.vehicle = currentVehicle
        
        saveContext()
        fetchLogs()
        return newLog
    }
    
    // Convenience overload for Double amounts (source-compatible)
    @discardableResult
    public func addLog(
        odometer: Double,
        volume: Double,
        totalCost: Double,
        stationName: String,
        latitude: Double = 0.0,
        longitude: Double = 0.0,
        locality: String? = nil,
        fuelGrade: String = "Petrol Octane 92",
        tripType: String = "City",
        notes: String = "",
        isFullTank: Bool = true,
        date: Date = Date(),
        fuelLevelBefore: Double? = nil
    ) throws -> FuelLog {
        guard !totalCost.isNaN && !totalCost.isInfinite && totalCost > 0 else {
            throw FuelLogValidationError.invalidTotalCost
        }
        return try addLog(
            odometer: odometer,
            volume: volume,
            totalCost: Decimal(totalCost),
            stationName: stationName,
            latitude: latitude,
            longitude: longitude,
            locality: locality,
            fuelGrade: fuelGrade,
            tripType: tripType,
            notes: notes,
            isFullTank: isFullTank,
            date: date,
            fuelLevelBefore: fuelLevelBefore
        )
    }
    
    public func toggleLogExclusion(_ log: FuelLog) {
        log.isExcluded.toggle()
        saveContext()
        fetchLogs()
    }
    
    public func deleteLog(_ log: FuelLog) {
        context.delete(log)
        saveContext()
        fetchLogs()
    }
    
    public func deleteLogs(at offsets: IndexSet) {
        offsets.map { logs[$0] }.forEach(context.delete)
        saveContext()
        fetchLogs()
    }
    
    public func clearAllLogs() {
        let fetchRequest: NSFetchRequest<NSFetchRequestResult> = NSFetchRequest(entityName: "FuelLog")
        let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
        do {
            try context.execute(deleteRequest)
            try context.save()
            fetchLogs()
        } catch {
            print("Failed to clear logs: \(error.localizedDescription)")
        }
    }
    
    private func saveContext() {
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            print("Core Data save error: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Realistic Sri Lankan Demo Seeding
    public func seedSriLankanDemoData() {
        // Clear existing data cleanly
        let logDelete = NSBatchDeleteRequest(fetchRequest: NSFetchRequest(entityName: "FuelLog"))
        let vehicleDelete = NSBatchDeleteRequest(fetchRequest: NSFetchRequest(entityName: "Vehicle"))
        _ = try? context.execute(logDelete)
        _ = try? context.execute(vehicleDelete)
        _ = try? context.save()
        
        let calendar = Calendar.current
        let now = Date()
        
        // 1. Vehicle 1: Toyota Prius (Hybrid Car - Level Tracked)
        let prius = Vehicle(context: context)
        prius.id = UUID()
        prius.name = "Toyota Prius"
        prius.plateNumber = "WP CAB-2045"
        prius.vehicleType = "Car"
        prius.tankCapacity = 45.0
        prius.tankCapacityLiters = 45.0
        prius.fuelTrackingMode = FuelTrackingMode.levelTracked.rawValue
        prius.initialOdometer = 44500.0
        prius.cityFuelConsumption = 18.0
        prius.highwayFuelConsumption = 22.0
        
        let priusLogs: [(daysAgo: Int, odo: Double, vol: Double, cost: Double, station: String, locality: String, lat: Double, lon: Double, fuel: String, trip: String, notes: String, level: Double)] = [
            (65, 44820.0, 18.5, 5753.50, "Ceypetco", "Colombo 07", 6.9014, 79.8631, "Petrol Octane 92", "City", "City driving refill", 0.55),
            (50, 45180.0, 19.0, 5909.00, "Lanka IOC", "Kandy", 7.2906, 80.6337, "Petrol Octane 92", "Highway", "Kandy weekend trip via Expressway", 0.60),
            (35, 45540.0, 18.2, 5660.20, "Sinopec", "Colombo 03", 6.9110, 79.8510, "Petrol Octane 92", "Mixed", "Regular commute fill", 0.58),
            (20, 45910.0, 18.8, 5846.80, "Shell / RM Parks", "Peliyagoda", 6.9650, 79.8850, "Petrol Octane 95 (Premium)", "Highway", "Premium run on highway", 0.59),
            (8,  46280.0, 18.6, 5784.60, "Ceypetco", "Welipenna Rest Area", 6.4421, 80.0542, "Petrol Octane 92", "Highway", "Southern Expressway run", 0.60),
            (1,  46650.0, 18.4, 5722.40, "Lanka IOC", "Galle Fort", 6.0329, 80.2168, "Petrol Octane 92", "Mixed", "Full tank before returning", 0.58)
        ]
        
        for item in priusLogs {
            let log = FuelLog(context: context)
            log.id = UUID()
            log.date = calendar.date(byAdding: .day, value: -item.daysAgo, to: now) ?? now
            log.odometer = item.odo
            log.volume = item.vol
            log.totalCost = NSDecimalNumber(value: item.cost)
            log.stationName = item.station
            log.locality = item.locality
            log.latitude = item.lat
            log.longitude = item.lon
            log.fuelGrade = item.fuel
            log.tripType = item.trip
            log.notes = item.notes
            log.isFullTank = true
            log.remainingFuelPercentBefore = NSNumber(value: item.level)
            log.vehicle = prius
        }
        
        // 2. Vehicle 2: Suzuki Wagon R (Compact Car - Expenses Only)
        let wagonR = Vehicle(context: context)
        wagonR.id = UUID()
        wagonR.name = "Suzuki Wagon R"
        wagonR.plateNumber = "WP CAD-7890"
        wagonR.vehicleType = "Car"
        wagonR.tankCapacity = 32.0
        wagonR.tankCapacityLiters = 32.0
        wagonR.fuelTrackingMode = FuelTrackingMode.expensesOnly.rawValue
        wagonR.initialOdometer = 28000.0
        wagonR.cityFuelConsumption = 14.0
        wagonR.highwayFuelConsumption = 18.0
        
        let wagonRLogs: [(daysAgo: Int, odo: Double, vol: Double, cost: Double, station: String, locality: String, lat: Double, lon: Double, fuel: String, trip: String, notes: String)] = [
            (40, 28310.0, 15.0, 4665.00, "Ceypetco", "Nugegoda", 6.8722, 79.8978, "Petrol Octane 92", "City", "Weekly office commuting"),
            (22, 28625.0, 14.8, 4602.80, "Lanka IOC", "Maharagama", 6.8480, 79.9268, "Petrol Octane 92", "City", "Refill after shopping run"),
            (5,  28940.0, 14.5, 4509.50, "Sinopec", "Rajagiriya", 6.9080, 79.8980, "Petrol Octane 92", "Mixed", "Economical city cruise")
        ]
        
        for item in wagonRLogs {
            let log = FuelLog(context: context)
            log.id = UUID()
            log.date = calendar.date(byAdding: .day, value: -item.daysAgo, to: now) ?? now
            log.odometer = item.odo
            log.volume = item.vol
            log.totalCost = NSDecimalNumber(value: item.cost)
            log.stationName = item.station
            log.locality = item.locality
            log.latitude = item.lat
            log.longitude = item.lon
            log.fuelGrade = item.fuel
            log.tripType = item.trip
            log.notes = item.notes
            log.isFullTank = true
            log.remainingFuelPercentBefore = nil // Expenses only mode has no fuel level
            log.vehicle = wagonR
        }
        
        // 3. Vehicle 3: Bajaj Pulsar 150 (Motorcycle - Level Tracked)
        let pulsar = Vehicle(context: context)
        pulsar.id = UUID()
        pulsar.name = "Bajaj Pulsar 150"
        pulsar.plateNumber = "SP BDG-4512"
        pulsar.vehicleType = "Motorcycle"
        pulsar.tankCapacity = 15.0
        pulsar.tankCapacityLiters = 15.0
        pulsar.fuelTrackingMode = FuelTrackingMode.levelTracked.rawValue
        pulsar.initialOdometer = 12000.0
        pulsar.cityFuelConsumption = 38.0
        pulsar.highwayFuelConsumption = 48.0
        
        let pulsarLogs: [(daysAgo: Int, odo: Double, vol: Double, cost: Double, station: String, locality: String, lat: Double, lon: Double, fuel: String, trip: String, notes: String, level: Double)] = [
            (30, 12380.0, 8.5, 2643.50, "Ceypetco", "Matara", 5.9549, 80.5550, "Petrol Octane 92", "City", "Coastal ride", 0.40),
            (12, 12760.0, 8.2, 2550.20, "Lanka IOC", "Tangalle", 6.0242, 80.7942, "Petrol Octane 92", "Highway", "Weekend beach ride", 0.45)
        ]
        
        for item in pulsarLogs {
            let log = FuelLog(context: context)
            log.id = UUID()
            log.date = calendar.date(byAdding: .day, value: -item.daysAgo, to: now) ?? now
            log.odometer = item.odo
            log.volume = item.vol
            log.totalCost = NSDecimalNumber(value: item.cost)
            log.stationName = item.station
            log.locality = item.locality
            log.latitude = item.lat
            log.longitude = item.lon
            log.fuelGrade = item.fuel
            log.tripType = item.trip
            log.notes = item.notes
            log.isFullTank = true
            log.remainingFuelPercentBefore = NSNumber(value: item.level)
            log.vehicle = pulsar
        }
        
        saveContext()
        fetchVehicles()
        selectedVehicle = prius
        fetchLogs()
    }
    
    // Backwards compatibility alias
    public func seedDemoData() {
        seedSriLankanDemoData()
    }
    
    public func loadSampleData() {
        seedSriLankanDemoData()
    }
    
    // MARK: - Decoupled Pure Statistics Engine
    public var fuelEntries: [FuelEntry] {
        logs.map { $0.toFuelEntry() }
    }
    
    public var currentFuelStats: FuelStatistics {
        let initialOdo = selectedVehicle?.initialOdometer ?? 0.0
        let city = selectedVehicle?.effectiveCityConsumption ?? 10.0
        let hwy = selectedVehicle?.effectiveHighwayConsumption ?? 15.0
        let tankCap = selectedVehicle?.effectiveTankCapacity ?? 45.0
        let mode = selectedVehicle?.trackingMode ?? .levelTracked
        return FuelStatistics.compute(
            entries: fuelEntries,
            initialOdometer: initialOdo,
            cityTarget: city,
            highwayTarget: hwy,
            tankCapacity: tankCap,
            trackingMode: mode
        )
    }
    
    public var hasEnoughFullTankData: Bool {
        currentFuelStats.averageEconomy != nil
    }
    
    public var currentBenchmark: BenchmarkComparison {
        let city = selectedVehicle?.effectiveCityConsumption ?? 10.0
        let hwy = selectedVehicle?.effectiveHighwayConsumption ?? 15.0
        return FuelStatistics.benchmark(
            actualEconomy: currentFuelStats.averageEconomy,
            cityTarget: city,
            highwayTarget: hwy,
            tripType: "Mixed"
        )
    }
    
    // MARK: - Core Calculations (Delegated to Pure Statistics)
    public var latestLog: FuelLog? {
        logs.first
    }
    
    public var totalSpentDecimal: Decimal {
        currentFuelStats.totalSpent
    }
    
    public var totalSpent: Double {
        NSDecimalNumber(decimal: currentFuelStats.totalSpent).doubleValue
    }
    
    public var totalFuelSpent: Double {
        totalSpent
    }
    
    public var totalVolume: Double {
        currentFuelStats.totalVolume
    }
    
    public var totalDistance: Double {
        currentFuelStats.totalDistance
    }
    
    public var totalDistanceTravelled: Double {
        totalDistance
    }
    
    public var averageFuelPriceDecimal: Decimal? {
        currentFuelStats.averageFuelPrice
    }
    
    public var averageFuelPrice: Double {
        currentFuelStats.averageFuelPrice.map { NSDecimalNumber(decimal: $0).doubleValue } ?? 0.0
    }
    
    public var averageEfficiency: Double {
        currentFuelStats.averageEconomy ?? 0.0
    }
    
    public var averageFuelEfficiency: Double {
        averageEfficiency
    }
    
    public var costPerKmDecimal: Decimal? {
        currentFuelStats.costPerKm
    }
    
    public var costPerKm: Double {
        currentFuelStats.costPerKm.map { NSDecimalNumber(decimal: $0).doubleValue } ?? 0.0
    }
    
    public var costPerDistance: Double {
        costPerKm
    }
    
    public var costPerDistanceUnit: Double {
        costPerKm
    }
    
    // MARK: - Trip-Specific Metrics
    public func tripDistance(for log: FuelLog) -> Double? {
        if let interval = currentFuelStats.intervals.first(where: { $0.endEntryId == log.id }) {
            return interval.distance
        }
        let sorted = logs.sorted { $0.date < $1.date }
        guard let index = sorted.firstIndex(where: { $0.id == log.id }) else { return nil }
        
        if index > 0 {
            let previous = sorted[index - 1]
            let diff = log.odometer - previous.odometer
            return diff > 0 ? diff : nil
        } else if let initial = selectedVehicle?.initialOdometer, initial > 0 && log.odometer > initial {
            return log.odometer - initial
        }
        return nil
    }
    
    public func tripEfficiency(for log: FuelLog) -> Double? {
        currentFuelStats.intervals.first(where: { $0.endEntryId == log.id })?.economy
    }
    
    // MARK: - History Month Grouping
    public func groupedLogs(from filteredLogs: [FuelLog]) -> [MonthGroup] {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        
        var groups: [String: [FuelLog]] = [:]
        var order: [String] = []
        
        for log in filteredLogs {
            let key = formatter.string(from: log.date)
            if groups[key] == nil {
                groups[key] = []
                order.append(key)
            }
            groups[key]?.append(log)
        }
        
        return order.compactMap { key in
            guard let items = groups[key] else { return nil }
            let total = items.reduce(Decimal.zero) { $0 + $1.costDecimal }
            let vol = items.reduce(0.0) { $0 + $1.volume }
            return MonthGroup(title: key, totalCost: total, totalVolume: vol, logs: items)
        }
    }
    
    // MARK: - Monthly Breakdown
    public var monthlyBreakdown: [MonthGroup] {
        groupedLogs(from: logs)
    }
    
    // MARK: - Filtered Analytics Queries
    public func logs(for timeRange: AnalyticsTimeRange) -> [FuelLog] {
        let calendar = Calendar.current
        let now = Date()
        
        switch timeRange {
        case .month:
            guard let cutoff = calendar.date(byAdding: .day, value: -30, to: now) else { return logs }
            return logs.filter { $0.date >= cutoff }
        case .sixMonths:
            guard let cutoff = calendar.date(byAdding: .month, value: -6, to: now) else { return logs }
            return logs.filter { $0.date >= cutoff }
        case .year:
            guard let cutoff = calendar.date(byAdding: .year, value: -1, to: now) else { return logs }
            return logs.filter { $0.date >= cutoff }
        case .all:
            return logs
        }
    }
    
    public func monthlySpendingTrend(for timeRange: AnalyticsTimeRange) -> [MonthlySpend] {
        let targetLogs = logs(for: timeRange)
        guard !targetLogs.isEmpty else { return [] }
        let calendar = Calendar.current
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM yy"
        
        var grouped: [String: (amount: Double, date: Date)] = [:]
        for log in targetLogs {
            let key = formatter.string(from: log.date)
            let existing = grouped[key]?.amount ?? 0.0
            let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: log.date)) ?? log.date
            grouped[key] = (amount: existing + log.totalCostDouble, date: startOfMonth)
        }
        
        return grouped.map { MonthlySpend(month: $0.key, amount: $0.value.amount, date: $0.value.date) }
            .sorted { $0.date < $1.date }
    }
    
    public func efficiencyTrend(for timeRange: AnalyticsTimeRange) -> [EfficiencyPoint] {
        let calendar = Calendar.current
        let now = Date()
        let cutoff: Date?
        switch timeRange {
        case .month:
            cutoff = calendar.date(byAdding: .day, value: -30, to: now)
        case .sixMonths:
            cutoff = calendar.date(byAdding: .month, value: -6, to: now)
        case .year:
            cutoff = calendar.date(byAdding: .year, value: -1, to: now)
        case .all:
            cutoff = nil
        }
        
        let filteredIntervals = currentFuelStats.intervals.filter { interval in
            if let cutoff = cutoff {
                return interval.endDate >= cutoff
            }
            return true
        }
        
        return filteredIntervals.map { interval in
            EfficiencyPoint(
                id: interval.endEntryId,
                date: interval.endDate,
                efficiency: interval.economy,
                stationName: interval.stationName.isEmpty ? "Fuel Station" : interval.stationName
            )
        }
    }
    
    public func priceTrend(for timeRange: AnalyticsTimeRange) -> [PricePoint] {
        return logs(for: timeRange).sorted { $0.date < $1.date }.compactMap { log in
            guard log.volume > 0 else { return nil }
            let price = log.totalCostDouble / log.volume
            guard price.isFinite && price > 0 else { return nil }
            return PricePoint(
                id: log.id,
                date: log.date,
                pricePerUnit: price,
                stationName: log.stationName ?? "Fuel Station"
            )
        }
    }
    
    public var efficiencyTrend: [EfficiencyPoint] {
        efficiencyTrend(for: .all)
    }
    
    public var monthlySpendingTrend: [MonthlySpend] {
        monthlySpendingTrend(for: .all)
    }
    
    public var priceTrend: [PricePoint] {
        priceTrend(for: .all)
    }
    
    public var bestTripEfficiency: Double? {
        currentFuelStats.bestEconomy
    }
    
    public var worstTripEfficiency: Double? {
        currentFuelStats.worstEconomy
    }
}
