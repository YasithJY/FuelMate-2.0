import SwiftUI

struct AddLogView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var viewModel: FuelLogViewModel
    @StateObject private var locationManager = LocationManager()
    
    @State private var odometer: String = ""
    @State private var volume: String = ""
    @State private var totalCost: String = ""
    @State private var stationName: String = ""
    
    var body: some View {
        Form {
            Section(header: Text("Details")) {
                TextField("Odometer", text: $odometer)
                    .keyboardType(.decimalPad)
                TextField("Volume (Gallons/Liters)", text: $volume)
                    .keyboardType(.decimalPad)
                TextField("Total Cost", text: $totalCost)
                    .keyboardType(.decimalPad)
            }
            
            Section(header: Text("Location")) {
                TextField("Station Name (Optional)", text: $stationName)
                if let loc = locationManager.location {
                    Text("GPS Acquired: \(loc.latitude), \(loc.longitude)")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Text("Fetching location...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Button(action: saveLog) {
                Text("Save Fuel Log")
                    .frame(maxWidth: .infinity)
                    .bold()
            }
            // Button is disabled until location is found and texts are populated
            .disabled(odometer.isEmpty || volume.isEmpty || totalCost.isEmpty || locationManager.location == nil)
        }
        .navigationTitle("Add Log")
    }
    
    private func saveLog() {
        guard let odo = Double(odometer),
              let vol = Double(volume),
              let cost = Double(totalCost),
              let loc = locationManager.location else { return }
        
        viewModel.addLog(
            odometer: odo,
            volume: vol,
            totalCost: cost,
            stationName: stationName,
            latitude: loc.latitude,
            longitude: loc.longitude
        )
        dismiss()
    }
}
