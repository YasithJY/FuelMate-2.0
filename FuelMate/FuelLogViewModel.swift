import Foundation
import CoreData
import SwiftUI

class FuelLogViewModel: ObservableObject {
    @Published var logs: [FuelLog] = []
    
    private let context = PersistenceController.shared.container.viewContext
    
    init() {
        fetchLogs()
    }
    
    func fetchLogs() {
        let request = NSFetchRequest<FuelLog>(entityName: "FuelLog")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \FuelLog.date, ascending: false)]
        do {
            logs = try context.fetch(request)
        } catch {
            print("Error fetching logs: \(error)")
        }
    }
    
    func addLog(odometer: Double, volume: Double, totalCost: Double, stationName: String, latitude: Double, longitude: Double) {
        let newLog = FuelLog(context: context)
        newLog.id = UUID()
        newLog.date = Date()
        newLog.odometer = odometer
        newLog.volume = volume
        newLog.totalCost = totalCost
        newLog.stationName = stationName.isEmpty ? nil : stationName
        newLog.latitude = latitude
        newLog.longitude = longitude
        
        saveContext()
    }
    
    private func saveContext() {
        do {
            try context.save()
            fetchLogs()
        } catch {
            print("Error saving log: \(error)")
        }
    }
    
    var totalFuelSpent: Double {
        logs.reduce(0) { $0 + $1.totalCost }
    }
    
    var averageFuelEfficiency: Double {
        guard logs.count > 1 else { return 0.0 }
        let sortedLogs = logs.sorted { $0.date < $1.date }
        let totalDistance = sortedLogs.last!.odometer - sortedLogs.first!.odometer
        let totalVolume = sortedLogs.dropFirst().reduce(0) { $0 + $1.volume }
        
        guard totalVolume > 0 else { return 0.0 }
        return totalDistance / totalVolume
    }
}
