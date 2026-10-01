import Foundation
import MapKit
import CoreLocation

// MARK: - Station Search Result Model
public struct StationResult: Identifiable, Hashable {
    public let id = UUID()
    public let title: String
    public let subtitle: String
    public let coordinate: CLLocationCoordinate2D
    public let brand: String?
    public let phone: String?
    public let url: URL?
    
    public init(
        title: String,
        subtitle: String,
        coordinate: CLLocationCoordinate2D,
        brand: String? = nil,
        phone: String? = nil,
        url: URL? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.coordinate = coordinate
        self.brand = brand
        self.phone = phone
        self.url = url
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(title)
        hasher.combine(coordinate.latitude)
        hasher.combine(coordinate.longitude)
    }
    
    public static func == (lhs: StationResult, rhs: StationResult) -> Bool {
        lhs.title == rhs.title &&
        lhs.coordinate.latitude == rhs.coordinate.latitude &&
        lhs.coordinate.longitude == rhs.coordinate.longitude
    }
}

// MARK: - MapKit Native Station Search Locator
public final class StationSearchService: ObservableObject {
    public static let shared = StationSearchService()
    
    @Published public var searchResults: [StationResult] = []
    @Published public var isSearching = false
    
    public init() {}
    
    /// Searches for nearby gas stations or petrol sheds using MapKit's MKLocalSearch
    public func searchStations(
        near coordinate: CLLocationCoordinate2D? = nil,
        query: String = "petrol shed",
        region: MKCoordinateRegion? = nil
    ) async -> [StationResult] {
        await MainActor.run { isSearching = true }
        defer {
            Task { @MainActor in self.isSearching = false }
        }
        
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query
        request.resultTypes = .pointOfInterest
        
        if let region = region {
            request.region = region
        } else if let coordinate = coordinate, coordinate.latitude != 0.0 && coordinate.longitude != 0.0 {
            request.region = MKCoordinateRegion(
                center: coordinate,
                latitudinalMeters: 15_000,
                longitudinalMeters: 15_000
            )
        } else {
            // Default center around Sri Lanka (Colombo)
            request.region = MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 6.9271, longitude: 79.8612),
                latitudinalMeters: 25_000,
                longitudinalMeters: 25_000
            )
        }
        
        do {
            let search = MKLocalSearch(request: request)
            let response = try await search.start()
            
            let stations = response.mapItems.map { item -> StationResult in
                let brand = detectBrand(from: item.name ?? "")
                let subtitle = item.placemark.title ?? item.placemark.locality ?? ""
                return StationResult(
                    title: item.name ?? "Fuel Station",
                    subtitle: subtitle,
                    coordinate: item.placemark.coordinate,
                    brand: brand,
                    phone: item.phoneNumber,
                    url: item.url
                )
            }
            
            await MainActor.run { self.searchResults = stations }
            return stations
        } catch {
            print("MKLocalSearch error: \(error.localizedDescription). Using Sri Lankan defaults.")
            let defaults = fallbackSriLankanStations(near: coordinate)
            await MainActor.run { self.searchResults = defaults }
            return defaults
        }
    }
    
    // MARK: - Sri Lankan Brand Classifier
    public func detectBrand(from title: String) -> String {
        let lower = title.lowercased()
        if lower.contains("ceypetco") || lower.contains("ceylon petroleum") || lower.contains("cpc") {
            return "Ceypetco"
        }
        if lower.contains("lioc") || lower.contains("lanka ioc") || lower.contains("ioc") || lower.contains("indian oil") {
            return "Lanka IOC"
        }
        if lower.contains("sinopec") {
            return "Sinopec"
        }
        if lower.contains("shell") || lower.contains("rm parks") {
            return "Shell / RM Parks"
        }
        return "Other"
    }
    
    // MARK: - Reliable Sri Lankan Fallback Filling Stations
    private func fallbackSriLankanStations(near coord: CLLocationCoordinate2D?) -> [StationResult] {
        return [
            StationResult(
                title: "Ceypetco Filling Station",
                subtitle: "Bauddhaloka Mawatha, Colombo 07",
                coordinate: CLLocationCoordinate2D(latitude: 6.9014, longitude: 79.8631),
                brand: "Ceypetco"
            ),
            StationResult(
                title: "Lanka IOC Petrol Shed",
                subtitle: "Peradeniya Road, Kandy",
                coordinate: CLLocationCoordinate2D(latitude: 7.2750, longitude: 80.6050),
                brand: "Lanka IOC"
            ),
            StationResult(
                title: "Sinopec Energy Station",
                subtitle: "Galle Road, Mount Lavinia",
                coordinate: CLLocationCoordinate2D(latitude: 6.8378, longitude: 79.8654),
                brand: "Sinopec"
            ),
            StationResult(
                title: "Shell / RM Parks Service Station",
                subtitle: "Negombo Road, Peliyagoda",
                coordinate: CLLocationCoordinate2D(latitude: 6.9650, longitude: 79.8850),
                brand: "Shell / RM Parks"
            ),
            StationResult(
                title: "Ceypetco Expressway Rest Area",
                subtitle: "Southern Expressway, Welipenna",
                coordinate: CLLocationCoordinate2D(latitude: 6.4421, longitude: 80.0542),
                brand: "Ceypetco"
            )
        ]
    }
}
