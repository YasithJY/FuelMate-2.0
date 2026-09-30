import SwiftUI

// MARK: - Unit System Enumeration
public enum UnitSystem: String, CaseIterable, Identifiable {
    case metric = "metric"
    case imperial = "imperial"
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .metric: return "Metric (km, L, km/L)"
        case .imperial: return "Imperial (mi, gal, MPG)"
        }
    }
    
    public var distanceUnit: String {
        switch self {
        case .metric: return "km"
        case .imperial: return "mi"
        }
    }
    
    public var volumeUnit: String {
        switch self {
        case .metric: return "L"
        case .imperial: return "gal"
        }
    }
    
    public var efficiencyUnit: String {
        switch self {
        case .metric: return "km/L"
        case .imperial: return "MPG"
        }
    }
    
    public var unitPriceLabel: String {
        switch self {
        case .metric: return "per Liter"
        case .imperial: return "per Gallon"
        }
    }
}

// MARK: - Unit & Localization Configuration Service
public final class UnitSettings: ObservableObject {
    public static let shared = UnitSettings()
    
    // Default to Metric for Sri Lankan standards
    @AppStorage("unitSystem") public var unitSystemRaw: String = UnitSystem.metric.rawValue {
        didSet { objectWillChange.send() }
    }
    
    // Default to Sri Lankan Rupee (Rs.)
    @AppStorage("currencySymbol") public var currencySymbol: String = "Rs." {
        didSet { objectWillChange.send() }
    }
    
    // Default target efficiency in km/L (15.0 km/L)
    @AppStorage("targetEfficiency") public var targetEfficiency: Double = 15.0 {
        didSet {
            if targetEfficiency <= 0 {
                targetEfficiency = 15.0
            }
            objectWillChange.send()
        }
    }
    
    public var unitSystem: UnitSystem {
        get {
            UnitSystem(rawValue: unitSystemRaw.lowercased()) ?? .metric
        }
        set {
            unitSystemRaw = newValue.rawValue
        }
    }
    
    // MARK: - Safe Formatting Utilities
    public func formatCurrency(_ amount: Double) -> String {
        guard !amount.isNaN && !amount.isInfinite else { return "\(currencySymbol) 0.00" }
        let safeAmount = max(0.0, amount)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let formattedNumber = formatter.string(from: NSNumber(value: safeAmount)) ?? String(format: "%.2f", safeAmount)
        return "\(currencySymbol) \(formattedNumber)"
    }
    
    public func formatDistance(_ distance: Double) -> String {
        guard !distance.isNaN && !distance.isInfinite else { return "0.0 \(unitSystem.distanceUnit)" }
        let safeDist = max(0.0, distance)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        let formatted = formatter.string(from: NSNumber(value: safeDist)) ?? String(format: "%.1f", safeDist)
        return "\(formatted) \(unitSystem.distanceUnit)"
    }
    
    public func formatVolume(_ volume: Double) -> String {
        guard !volume.isNaN && !volume.isInfinite else { return "0.00 \(unitSystem.volumeUnit)" }
        let safeVol = max(0.0, volume)
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let formatted = formatter.string(from: NSNumber(value: safeVol)) ?? String(format: "%.2f", safeVol)
        return "\(formatted) \(unitSystem.volumeUnit)"
    }
    
    public func formatEfficiency(_ efficiency: Double) -> String {
        guard !efficiency.isNaN && !efficiency.isInfinite && efficiency > 0 else { return "--" }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        let formatted = formatter.string(from: NSNumber(value: efficiency)) ?? String(format: "%.1f", efficiency)
        return "\(formatted) \(unitSystem.efficiencyUnit)"
    }
    
    public func formatUnitPrice(_ price: Double) -> String {
        guard !price.isNaN && !price.isInfinite && price > 0 else {
            return "\(currencySymbol) 0.00/\(unitSystem.volumeUnit)"
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        let formatted = formatter.string(from: NSNumber(value: price)) ?? String(format: "%.2f", price)
        return "\(currencySymbol) \(formatted)/\(unitSystem.volumeUnit)"
    }
    
    // MARK: - RFC-4180 Compliant CSV Export
    public func exportCSV(logs: [FuelLog], vehicleName: String? = nil) -> String {
        var csv = "Vehicle,ID,Date,Station,Locality,Odometer (\(unitSystem.distanceUnit)),Volume (\(unitSystem.volumeUnit)),Total Cost (\(currencySymbol)),Unit Price,Fuel Grade,Full Tank,Latitude,Longitude,Notes\r\n"
        
        let isoFormatter = ISO8601DateFormatter()
        let sortedLogs = logs.sorted { $0.date > $1.date }
        
        for log in sortedLogs {
            let vehicle = escapeCSVField(log.vehicle?.name ?? vehicleName ?? "Default Vehicle")
            let id = log.id.uuidString
            let date = isoFormatter.string(from: log.date)
            let station = escapeCSVField(log.stationName ?? "Fuel Station")
            let locality = escapeCSVField(log.locality ?? "")
            let odometer = String(format: "%.1f", max(0.0, log.odometer))
            let volume = String(format: "%.2f", max(0.0, log.volume))
            let totalCost = String(format: "%.2f", max(0.0, log.totalCost))
            let unitPrice = String(format: "%.2f", log.unitPrice)
            let grade = escapeCSVField(log.fuelGrade ?? "Petrol 92 Octane")
            let fullTank = log.isFullTank ? "YES" : "NO"
            let lat = String(format: "%.6f", log.latitude)
            let lon = String(format: "%.6f", log.longitude)
            let notes = escapeCSVField(log.notes ?? "")
            
            let row = "\(vehicle),\(id),\(date),\(station),\(locality),\(odometer),\(volume),\(totalCost),\(unitPrice),\(grade),\(fullTank),\(lat),\(lon),\(notes)\r\n"
            csv.append(row)
        }
        return csv
    }
    
    private func escapeCSVField(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") || value.contains("\r") {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }
}
