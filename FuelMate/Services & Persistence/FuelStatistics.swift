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
    
    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        odometer: Double,
        volume: Double,
        totalCost: Decimal,
        isFullTank: Bool = true,
        tripType: String = "City",
        stationName: String = "",
        fuelGrade: String = ""
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
    }
    
    public var unitPrice: Decimal {
        guard volume > 0 else { return 0 }
        return (totalCost / Decimal(volume))
    }
}

// MARK: - Full-Tank Interval Computation Result
public struct FuelInterval: Identifiable, Equatable {
    public var id: UUID { endEntryId }
    public let startEntryId: UUID
    public let endEntryId: UUID
    public let startDate: Date
    public let endDate: Date
    public let startOdometer: Double
    public let endOdometer: Double
    public let distance: Double
    public let consumedVolume: Double // Sum of partial fills in between + final full tank
    public let totalCost: Decimal
    public let economy: Double // distance / consumedVolume (km/L)
    public let tripType: String
    public let stationName: String
    
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
        stationName: String
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
    public let averageEconomy: Double? // Nil if fewer than 2 full-tank fills exist
    public let costPerKm: Decimal?
    public let averageFuelPrice: Decimal?
    public let intervals: [FuelInterval]
    public let bestEconomy: Double?
    public let worstEconomy: Double?
    public let fullTankFillCount: Int
    public let totalFillCount: Int
    
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
        totalFillCount: Int
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
    }
    
    // MARK: - Factory Calculation Method
    public static func compute(
        entries: [FuelEntry],
        initialOdometer: Double = 0.0,
        cityTarget: Double = 10.0,
        highwayTarget: Double = 15.0
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
                totalFillCount: 0
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
        
        // Full-Tank Intervals Calculation
        let calculatedIntervals = computeFullTankIntervals(from: sorted)
        let fullTankFills = sorted.filter { $0.isFullTank }.count
        
        // Average economy across full-tank spans
        let avgEconomy: Double?
        if let firstFull = sorted.first(where: { $0.isFullTank }),
           let lastFull = sorted.last(where: { $0.isFullTank }),
           firstFull.id != lastFull.id,
           lastFull.odometer > firstFull.odometer {
            // Find all entries strictly after firstFull up to and including lastFull
            if let firstIdx = sorted.firstIndex(where: { $0.id == firstFull.id }),
               let lastIdx = sorted.firstIndex(where: { $0.id == lastFull.id }),
               firstIdx < lastIdx {
                let rangeEntries = sorted[(firstIdx + 1)...lastIdx]
                let spanVolume = rangeEntries.reduce(0.0) { $0 + max(0.0, $1.volume) }
                let spanDistance = lastFull.odometer - firstFull.odometer
                if spanVolume > 0 && spanDistance > 0 {
                    let eco = spanDistance / spanVolume
                    avgEconomy = eco.isFinite && eco > 0 ? eco : nil
                } else {
                    avgEconomy = nil
                }
            } else {
                avgEconomy = nil
            }
        } else {
            avgEconomy = nil
        }
        
        let validEconomies = calculatedIntervals.map { $0.economy }
        let best = validEconomies.max()
        let worst = validEconomies.min()
        
        return FuelStatistics(
            totalDistance: totalDist,
            totalVolume: totalVol,
            totalSpent: totalCost,
            averageEconomy: avgEconomy,
            costPerKm: costKm,
            averageFuelPrice: avgPrice,
            intervals: calculatedIntervals,
            bestEconomy: best,
            worstEconomy: worst,
            fullTankFillCount: fullTankFills,
            totalFillCount: sorted.count
        )
    }
    
    // MARK: - Full-Tank Interval Computation
    /// Calculates economy only between consecutive full-tank fills, summing any partial fills in between.
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
                    // Reset accumulator for next interval
                    lastFullTankEntry = entry
                    accumulatedVolume = 0.0
                    accumulatedCost = .zero
                }
            } else {
                if entry.isFullTank {
                    // First full tank anchor established
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
        estimatedEconomy: Double?
    ) -> [SanityWarning] {
        var warnings: [SanityWarning] = []
        
        // 1. Volume exceeds tank size
        if tankCapacity > 0 && enteredVolume > tankCapacity {
            let excess = enteredVolume - tankCapacity
            warnings.append(SanityWarning(
                type: .volumeExceedsTank,
                message: String(format: "Entered volume (%.1f L) exceeds your vehicle's configured tank capacity (%.0f L) by %.1f L.", enteredVolume, tankCapacity, excess)
            ))
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
