import SwiftUI
import MapKit

struct HistoryView: View {
    @ObservedObject var viewModel: FuelLogViewModel
    
    var body: some View {
        List {
            ForEach(viewModel.logs) { log in
                NavigationLink(destination: LogDetailView(log: log)) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(log.stationName ?? "Unknown Station")
                                .font(.headline)
                            Text("\(log.date, formatter: dateFormatter)")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text(String(format: "$%.2f", log.totalCost))
                            .bold()
                    }
                }
            }
        }
        .navigationTitle("History")
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

struct LogDetailView: View {
    let log: FuelLog
    
    var body: some View {
        VStack {
            // Using MapKit for iOS 17+
            Map(initialPosition: .region(MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: log.latitude, longitude: log.longitude),
                span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
            ))) {
                Marker(log.stationName ?? "Fuel Station", coordinate: CLLocationCoordinate2D(latitude: log.latitude, longitude: log.longitude))
            }
            .frame(height: 300)
            .cornerRadius(15)
            .padding()
            
            List {
                Section(header: Text("Log Details")) {
                    DetailRow(title: "Date", value: log.date.formatted())
                    DetailRow(title: "Odometer", value: "\(log.odometer)")
                    DetailRow(title: "Volume", value: "\(log.volume)")
                    DetailRow(title: "Total Cost", value: String(format: "$%.2f", log.totalCost))
                }
            }
        }
        .navigationTitle(log.stationName ?? "Detail")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct DetailRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .bold()
        }
    }
}
