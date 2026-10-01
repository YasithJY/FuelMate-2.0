import SwiftUI
import MapKit
import CoreLocation

public struct StationPickerMapView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var searchService = StationSearchService()
    
    // Binding to return selected station data to AddLogView
    @Binding public var selectedStationName: String
    @Binding public var selectedLatitude: Double
    @Binding public var selectedLongitude: Double
    @Binding public var selectedLocality: String?
    
    @State private var cameraPosition: MapCameraPosition
    @State private var searchText: String = ""
    @State private var selectedStation: StationResult?
    @State private var droppedPinCoordinate: CLLocationCoordinate2D?
    @State private var isSearching = false
    
    public init(
        stationName: Binding<String>,
        latitude: Binding<Double>,
        longitude: Binding<Double>,
        locality: Binding<String?>
    ) {
        self._selectedStationName = stationName
        self._selectedLatitude = latitude
        self._selectedLongitude = longitude
        self._selectedLocality = locality
        
        // Initial center: if coordinates already exist, use them; otherwise default to Colombo, Sri Lanka
        if latitude.wrappedValue != 0.0 && longitude.wrappedValue != 0.0 {
            let center = CLLocationCoordinate2D(latitude: latitude.wrappedValue, longitude: longitude.wrappedValue)
            _cameraPosition = State(initialValue: .region(MKCoordinateRegion(
                center: center,
                latitudinalMeters: 8_000,
                longitudinalMeters: 8_000
            )))
        } else {
            let colombo = CLLocationCoordinate2D(latitude: 6.9271, longitude: 79.8612)
            _cameraPosition = State(initialValue: .region(MKCoordinateRegion(
                center: colombo,
                latitudinalMeters: 18_000,
                longitudinalMeters: 18_000
            )))
        }
    }
    
    public var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                // Interactive Apple Map
                Map(position: $cameraPosition, selection: $selectedStation) {
                    // Searched Station Markers
                    ForEach(searchService.searchResults) { station in
                        Marker(station.title, coordinate: station.coordinate)
                            .tint(AppTheme.stationColor(for: station.title))
                            .tag(station)
                    }
                    
                    // User Dropped Custom Pin (if tapped outside pre-existing stations)
                    if let customCoord = droppedPinCoordinate {
                        Marker("Selected Location", coordinate: customCoord)
                            .tint(.purple)
                    }
                }
                .mapControls {
                    MapUserLocationButton()
                    MapCompass()
                    MapScaleView()
                }
                
                // Top Search Overlay
                VStack(spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                        
                        TextField("Search 'Ceypetco', 'petrol shed', 'LIOC'...", text: $searchText)
                            .onSubmit {
                                performSearch()
                            }
                        
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Button("Search") {
                            performSearch()
                        }
                        .bold()
                        .foregroundColor(.blue)
                    }
                    .padding(12)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.12), radius: 6, x: 0, y: 3)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    
                    // Quick Filter Pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(["Ceypetco", "Lanka IOC", "Sinopec", "Shell", "petrol shed"], id: \.self) { term in
                                Button(action: {
                                    Haptics.selection()
                                    searchText = term
                                    performSearch()
                                }) {
                                    Text(term)
                                        .font(.caption)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                                        .clipShape(Capsule())
                                        .shadow(color: Color.black.opacity(0.05), radius: 2)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                    
                    Spacer()
                }
                
                // Bottom Pin Selection Confirmation Card
                if let station = selectedStation {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .top, spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.stationColor(for: station.title).opacity(0.16))
                                    .frame(width: 48, height: 48)
                                Image(systemName: "fuelpump.fill")
                                    .foregroundColor(AppTheme.stationColor(for: station.title))
                                    .font(.title3)
                            }
                            
                            VStack(alignment: .leading, spacing: 3) {
                                Text(station.title)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                if !station.subtitle.isEmpty {
                                    Text(station.subtitle)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(2)
                                }
                                
                                Text(String(format: "Coordinates: %.4f, %.4f", station.coordinate.latitude, station.coordinate.longitude))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                        }
                        
                        Button(action: {
                            confirmSelection(station: station)
                        }) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("Populate Station Details")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(AppTheme.primaryGradient)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }
                    }
                    .padding(16)
                    .background(Color(uiColor: .systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: -2)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle("Station Locator")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .task {
                let initialCoord = CLLocationCoordinate2D(
                    latitude: selectedLatitude != 0 ? selectedLatitude : 6.9271,
                    longitude: selectedLongitude != 0 ? selectedLongitude : 79.8612
                )
                _ = await searchService.searchStations(near: initialCoord)
            }
        }
    }
    
    private func performSearch() {
        hideKeyboard()
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "petrol shed" : searchText
        Task {
            _ = await searchService.searchStations(query: query)
        }
    }
    
    private func confirmSelection(station: StationResult) {
        Haptics.success()
        selectedStationName = station.title
        selectedLatitude = station.coordinate.latitude
        selectedLongitude = station.coordinate.longitude
        selectedLocality = station.subtitle.isEmpty ? nil : station.subtitle
        dismiss()
    }
}
