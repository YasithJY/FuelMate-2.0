import Foundation

// MARK: - Pure Fuel Record Model (Decoupled from Core Data)
public struct FuelEntry: Identifiable, Equatable {
    public let id: UUID
    public let date: Date
    public let odometer: Double
    public let volume: Double
    public let totalCost: Decimal
    public let isFullTank: Bool
    public let tripType: String // "City", "Highway", "Mixed"
    public let stationName: String
    public let fuelGrade: String
    public let fuelLevelBefore: Double?
    public let isExcluded: Bool
    
    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        odometer: Double,
        volume: Double,
        totalCost: Decimal,
        isFullTank: Bool = true,
        tripType: String = "City",
        stationName: String = "",
        fuelGrade: String = "",
        fuelLevelBefore: Double? = nil,
        isExcluded: Bool = false
    ) {
        self.id = id
        self.date = date
        self.odometer = odometer
        self.volume = volume
        self.totalCost = totalCost
        self.isFullTank = isFullTank
        self.tripType = tripType
        self.stationName = stationName
        self.fuelGrade = fuelGrade
        self.fuelLevelBefore = fuelLevelBefore
        self.isExcluded = isExcluded
    }
    
    public var unitPrice: Decimal {
        guard volume > 0 else { return 0 }
        return (totalCost / Decimal(volume))
    }
}

// MARK: - Full-Tank / Level-Tracked Interval Computation Result
public struct FuelInterval: Identifiable, Equatable {
    public var id: UUID { endEntryId }
    public let startEntryId: UUID
    public let endEntryId: UUID
    public let startDate: Date
    public let endDate: Date
    public let startOdometer: Double
    public let endOdometer: Double
    public let distance: Double
    public let consumedVolume: Double // Fuel used in liters
    public let totalCost: Decimal
    public let economy: Double // distance / consumedVolume (km/L)
    public let tripType: String
    public let stationName: String
    public let isImplausible: Bool
    public let isExcluded: Bool
    public let fuelLevelBeforeA: Double?
    public let fuelLevelAfterA: Double?
    public let fuelLevelBeforeB: Double?
    
    public init(
        startEntryId: UUID,
        endEntryId: UUID,
        startDate: Date,
        endDate: Date,
        startOdometer: Double,
        endOdometer: Double,
        distance: Double,
        consumedVolume: Double,
        totalCost: Decimal,
        economy: Double,
        tripType: String,
        stationName: String,
        isImplausible: Bool = false,
        isExcluded: Bool = false,
        fuelLevelBeforeA: Double? = nil,
        fuelLevelAfterA: Double? = nil,
        fuelLevelBeforeB: Double? = nil
    ) {
        self.startEntryId = startEntryId
        self.endEntryId = endEntryId
        self.startDate = startDate
        self.endDate = endDate
        self.startOdometer = startOdometer
        self.endOdometer = endOdometer
        self.distance = distance
        self.consumedVolume = consumedVolume
        self.totalCost = totalCost
        self.economy = economy
        self.tripType = tripType
        self.stationName = stationName
        self.isImplausible = isImplausible
        self.isExcluded = isExcluded
        self.fuelLevelBeforeA = fuelLevelBeforeA
        self.fuelLevelAfterA = fuelLevelAfterA
        self.fuelLevelBeforeB = fuelLevelBeforeB
    }
}

// MARK: - Benchmark Result
public struct BenchmarkComparison: Equatable {
    public let actualEconomy: Double
    public let targetEconomy: Double
    public let percentageDelta: Double // e.g. +12.5% or -15.0%
    public let status: Status
    
    public enum Status: String, Equatable {
        case aboveHighway = "Above Highway Target"
        case onTarget = "On Target"
        case belowCity = "Below City Target"
        case insufficientData = "Not enough data"
    }
    
    public init(actualEconomy: Double, targetEconomy: Double, percentageDelta: Double, status: Status) {
        self.actualEconomy = actualEconomy
        self.targetEconomy = targetEconomy
        self.percentageDelta = percentageDelta
        self.status = status
    }
}

// MARK: - Data Sanity Warning Model
public struct SanityWarning: Identifiable, Equatable {
    public var id: String { type.rawValue }
    public let type: WarningType
    public let message: String
    
    public enum WarningType: String, Equatable {
        case volumeExceedsTank = "volume_exceeds_tank"
        case odometerJump = "odometer_jump"
        case economyDeviation = "economy_deviation"
    }
    
    public init(type: WarningType, message: String) {
        self.type = type
        self.message = message
    }
}

// MARK: - Pure FuelStatistics Engine (Zero Core Data / Zero SwiftUI dependencies)
public struct FuelStatistics: Equatable {
    public let totalDistance: Double
    public let totalVolume: Double
    public let totalSpent: Decimal
    public let averageEconomy: Double? // Headline rolling average of last 3-5 valid intervals (Nil if no valid intervals exist or if expenses-only)
    public let costPerKm: Decimal?
    public let averageFuelPrice: Decimal?
    public let intervals: [FuelInterval]
    public let bestEconomy: Double?
    public let worstEconomy: Double?
    public let fullTankFillCount: Int
    public let totalFillCount: Int
    public let rollingIntervalCount: Int
    public let rollingAverageEconomy: Double?
    public let trackingMode: FuelTrackingMode
    
    public init(
        totalDistance: Double,
        totalVolume: Double,
        totalSpent: Decimal,
        averageEconomy: Double?,
        costPerKm: Decimal?,
        averageFuelPrice: Decimal?,
        intervals: [FuelInterval],
        bestEconomy: Double?,
        worstEconomy: Double?,
        fullTankFillCount: Int,
        totalFillCount: Int,
        rollingIntervalCount: Int = 0,
        rollingAverageEconomy: Double? = nil,
        trackingMode: FuelTrackingMode = .levelTracked
    ) {
        self.totalDistance = totalDistance
        self.totalVolume = totalVolume
        self.totalSpent = totalSpent
        self.averageEconomy = averageEconomy
        self.costPerKm = costPerKm
        self.averageFuelPrice = averageFuelPrice
        self.intervals = intervals
        self.bestEconomy = bestEconomy
        self.worstEconomy = worstEconomy
        self.fullTankFillCount = fullTankFillCount
        self.totalFillCount = totalFillCount
        self.rollingIntervalCount = rollingIntervalCount
        self.rollingAverageEconomy = rollingAverageEconomy
        self.trackingMode = trackingMode
    }
    
    // MARK: - Factory Calculation Method
    public static func compute(
        entries: [FuelEntry],
        initialOdometer: Double = 0.0,
        cityTarget: Double = 10.0,
        highwayTarget: Double = 15.0,
        tankCapacity: Double = 45.0,
        trackingMode: FuelTrackingMode = .levelTracked
    ) -> FuelStatistics {
        guard !entries.isEmpty else {
            return FuelStatistics(
                totalDistance: 0.0,
                totalVolume: 0.0,
                totalSpent: .zero,
                averageEconomy: nil,
                costPerKm: nil,
                averageFuelPrice: nil,
                intervals: [],
                bestEconomy: nil,
                worstEconomy: nil,
                fullTankFillCount: 0,
                totalFillCount: 0,
                rollingIntervalCount: 0,
                rollingAverageEconomy: nil,
                trackingMode: trackingMode
            )
        }
        
        // Sort chronologically ascending (oldest to newest)
        let sorted = entries.sorted {
            if $0.date != $1.date {
                return $0.date < $1.date
            }
            return $0.odometer < $1.odometer
        }
        
        let totalVol = sorted.reduce(0.0) { $0 + max(0.0, $1.volume) }
        let totalCost = sorted.reduce(Decimal.zero) { $0 + max(.zero, $1.totalCost) }
        
        // Tracked distance
        let totalDist: Double
        if sorted.count > 1 {
            let odos = sorted.map { $0.odometer }
            let minOdo = odos.min() ?? 0.0
            let maxOdo = odos.max() ?? 0.0
            totalDist = max(0.0, maxOdo - minOdo)
        } else if let single = sorted.first, initialOdometer > 0 {
            totalDist = max(0.0, single.odometer - initialOdometer)
        } else {
            totalDist = 0.0
        }
        
        // Cost per km
        let costKm: Decimal?
        if totalDist > 0 {
            let distDec = Decimal(totalDist)
            costKm = (totalCost / distDec)
        } else {
            costKm = nil
        }
        
        // Average fuel price
        let avgPrice: Decimal?
        if totalVol > 0 {
            avgPrice = (totalCost / Decimal(totalVol))
        } else {
            avgPrice = nil
        }
        
        let fullTankFills = sorted.filter { $0.isFullTank }.count
        
        // Option 2: Expenses Only -> returns no economy values at all
        if trackingMode == .expensesOnly {
            return FuelStatistics(
                totalDistance: totalDist,
                totalVolume: totalVol,
                totalSpent: totalCost,
                averageEconomy: nil,
                costPerKm: costKm,
                averageFuelPrice: avgPrice,
                intervals: [],
                bestEconomy: nil,
                worstEconomy: nil,
                fullTankFillCount: fullTankFills,
                totalFillCount: sorted.count,
                rollingIntervalCount: 0,
                rollingAverageEconomy: nil,
                trackingMode: .expensesOnly
            )
        }
        
        // Option 1: Level Tracked Mode
        let calculatedIntervals = computeLevelTrackedIntervals(
            from: sorted,
            tankCapacity: tankCapacity,
            cityTarget: cityTarget,
            highwayTarget: highwayTarget
        )
        
        let validIntervals = calculatedIntervals.filter { !$0.isExcluded }
        let rollingAvg: Double?
        let rollingCount: Int
        
        if validIntervals.isEmpty {
            rollingAvg = nil
            rollingCount = 0
        } else {
            // Rolling average of the last 3-5 valid intervals (or all available if 1 or 2)
            let sampleCount = min(5, validIntervals.count)
            let sample = Array(validIntervals.suffix(sampleCount))
            rollingCount = sampleCount
            rollingAvg = sample.reduce(0.0) { $0 + $1.economy } / Double(sampleCount)
        }
        
        let validEconomies = validIntervals.map { $0.economy }
        let best = validEconomies.max()
        let worst = validEconomies.min()
        
        return FuelStatistics(
            totalDistance: totalDist,
            totalVolume: totalVol,
            totalSpent: totalCost,
            averageEconomy: rollingAvg,
            costPerKm: costKm,
            averageFuelPrice: avgPrice,
            intervals: calculatedIntervals,
            bestEconomy: best,
            worstEconomy: worst,
            fullTankFillCount: fullTankFills,
            totalFillCount: sorted.count,
            rollingIntervalCount: rollingCount,
            rollingAverageEconomy: rollingAvg,
            trackingMode: .levelTracked
        )
    }
    
    // MARK: - Level-Tracked Interval Computation
    public static func computeLevelTrackedIntervals(
        from sortedEntries: [FuelEntry],
        tankCapacity: Double,
        cityTarget: Double,
        highwayTarget: Double
    ) -> [FuelInterval] {
        guard tankCapacity > 0, sortedEntries.count >= 2 else { return [] }
        var intervals: [FuelInterval] = []
        
        for i in 0..<(sortedEntries.count - 1) {
            let entryA = sortedEntries[i]
            let entryB = sortedEntries[i + 1]
            
            // Skip intervals where either log lacks a level value
            guard let levelBeforeA = entryA.fuelLevelBefore,
                  let levelBeforeB = entryB.fuelLevelBefore else {
                continue
            }
            
            // Level after refuel A = 100% if marked full, otherwise min(1.0, levelBefore + volume / tankCapacity)
            let levelAfterA: Double
            if entryA.isFullTank {
                levelAfterA = 1.0
            } else {
                levelAfterA = min(1.0, levelBeforeA + (max(0.0, entryA.volume) / tankCapacity))
            }
            
            // Fuel used between log A and next log B = (levelAfter(A) - levelBefore(B)) * tankCapacity
            let fuelUsed = (levelAfterA - levelBeforeB) * tankCapacity
            let distance = entryB.odometer - entryA.odometer
            
            // Skip intervals where fuelUsed <= 0, distance <= 0. Never divide by zero.
            guard distance > 0, fuelUsed > 0 else { continue }
            
            let economy = distance / fuelUsed
            guard economy.isFinite, economy > 0 else { continue }
            
            // Plausibility check: flag if economy is more than 40% away from vehicle baseline
            let baseline: Double
            switch entryB.tripType.lowercased() {
            case "city":
                baseline = max(0.1, cityTarget)
            case "highway":
                baseline = max(0.1, highwayTarget)
            default:
                baseline = max(0.1, (cityTarget + highwayTarget) / 2.0)
            }
            let deviation = abs(economy - baseline) / baseline
            let isImplausible = deviation > 0.40
            let isExcluded = entryB.isExcluded
            
            intervals.append(FuelInterval(
                startEntryId: entryA.id,
                endEntryId: entryB.id,
                startDate: entryA.date,
                endDate: entryB.date,
                startOdometer: entryA.odometer,
                endOdometer: entryB.odometer,
                distance: distance,
                consumedVolume: fuelUsed,
                totalCost: entryB.totalCost,
                economy: economy,
                tripType: entryB.tripType,
                stationName: entryB.stationName,
                isImplausible: isImplausible,
                isExcluded: isExcluded,
                fuelLevelBeforeA: levelBeforeA,
                fuelLevelAfterA: levelAfterA,
                fuelLevelBeforeB: levelBeforeB
            ))
        }
        
        return intervals
    }
    
    // MARK: - Legacy Full-Tank Interval Computation (Preserved for compatibility)
    public static func computeFullTankIntervals(from sortedEntries: [FuelEntry]) -> [FuelInterval] {
        var intervals: [FuelInterval] = []
        var lastFullTankEntry: FuelEntry? = nil
        var accumulatedVolume: Double = 0.0
        var accumulatedCost: Decimal = .zero
        
        for entry in sortedEntries {
            if let prevFull = lastFullTankEntry {
                accumulatedVolume += max(0.0, entry.volume)
                accumulatedCost += max(.zero, entry.totalCost)
                
                if entry.isFullTank {
                    let distance = entry.odometer - prevFull.odometer
                    if distance > 0 && accumulatedVolume > 0 {
                        let eco = distance / accumulatedVolume
                        if eco.isFinite && eco > 0 {
                            intervals.append(FuelInterval(
                                startEntryId: prevFull.id,
                                endEntryId: entry.id,
                                startDate: prevFull.date,
                                endDate: entry.date,
                                startOdometer: prevFull.odometer,
                                endOdometer: entry.odometer,
                                distance: distance,
                                consumedVolume: accumulatedVolume,
                                totalCost: accumulatedCost,
                                economy: eco,
                                tripType: entry.tripType,
                                stationName: entry.stationName
                            ))
                        }
                    }
                    lastFullTankEntry = entry
                    accumulatedVolume = 0.0
                    accumulatedCost = .zero
                }
            } else {
                if entry.isFullTank {
                    lastFullTankEntry = entry
                    accumulatedVolume = 0.0
                    accumulatedCost = .zero
                }
            }
        }
        
        return intervals
    }
    
    // MARK: - Benchmarking Against City / Highway / Mixed Targets
    public static func benchmark(
        actualEconomy: Double?,
        cityTarget: Double,
        highwayTarget: Double,
        tripType: String = "Mixed"
    ) -> BenchmarkComparison {
        guard let actual = actualEconomy, actual > 0 else {
            return BenchmarkComparison(
                actualEconomy: 0.0,
                targetEconomy: (cityTarget + highwayTarget) / 2.0,
                percentageDelta: 0.0,
                status: .insufficientData
            )
        }
        
        let safeCity = max(0.1, cityTarget)
        let safeHighway = max(safeCity, highwayTarget)
        
        let target: Double
        switch tripType.lowercased() {
        case "city":
            target = safeCity
        case "highway":
            target = safeHighway
        default:
            target = (safeCity + safeHighway) / 2.0
        }
        
        let delta = ((actual - target) / target) * 100.0
        
        let status: BenchmarkComparison.Status
        if actual >= safeHighway {
            status = .aboveHighway
        } else if actual >= safeCity {
            status = .onTarget
        } else {
            status = .belowCity
        }
        
        return BenchmarkComparison(
            actualEconomy: actual,
            targetEconomy: target,
            percentageDelta: delta,
            status: status
        )
    }
    
    // MARK: - Data Sanity Warnings (Non-Blocking)
    public static func validateSanity(
        enteredVolume: Double,
        tankCapacity: Double,
        enteredOdometer: Double,
        previousOdometer: Double?,
        baselineEconomy: Double,
        estimatedEconomy: Double?,
        remainingFuelPercent: Double? = nil
    ) -> [SanityWarning] {
        var warnings: [SanityWarning] = []
        
        // 1. Volume + remaining level exceeds tank size by > 5%
        if tankCapacity > 0 {
            if let level = remainingFuelPercent {
                let remainingLiters = level * tankCapacity
                let totalFuel = enteredVolume + remainingLiters
                if totalFuel > (tankCapacity * 1.05) {
                    let excess = totalFuel - tankCapacity
                    let excessPercent = Int(round(((totalFuel - tankCapacity) / tankCapacity) * 100))
                    warnings.append(SanityWarning(
                        type: .volumeExceedsTank,
                        message: String(format: "Total fuel (%.1f L volume + %.1f L remaining = %.1f L) exceeds tank capacity (%.0f L) by %.1f L (%d%%).", enteredVolume, remainingLiters, totalFuel, tankCapacity, excess, excessPercent)
                    ))
                }
            } else if enteredVolume > tankCapacity {
                let excess = enteredVolume - tankCapacity
                warnings.append(SanityWarning(
                    type: .volumeExceedsTank,
                    message: String(format: "Entered volume (%.1f L) exceeds your vehicle's configured tank capacity (%.0f L) by %.1f L.", enteredVolume, tankCapacity, excess)
                ))
            }
        }
        
        // 2. Odometer jump above threshold (>1,500 km in a single fill-up)
        if let prev = previousOdometer, prev > 0 {
            let jump = enteredOdometer - prev
            if jump > 1500.0 {
                warnings.append(SanityWarning(
                    type: .odometerJump,
                    message: String(format: "Odometer jump (+%.0f km) is unusually high for a single tank. Please verify your odometer entry.", jump)
                ))
            }
        }
        
        // 3. Economy more than 40% away from vehicle baseline
        if let eco = estimatedEconomy, eco > 0 && baselineEconomy > 0 {
            let deviation = abs(eco - baselineEconomy) / baselineEconomy
            if deviation > 0.40 {
                let diffPercent = Int(deviation * 100)
                let direction = eco < baselineEconomy ? "below" : "above"
                warnings.append(SanityWarning(
                    type: .economyDeviation,
                    message: String(format: "Estimated trip economy (%.1f km/L) is %d%% %@ your baseline target (%.1f km/L).", eco, diffPercent, direction, baselineEconomy)
                ))
            }
        }
        
        return warnings
    }
}
