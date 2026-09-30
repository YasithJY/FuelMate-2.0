import Foundation
import CoreLocation
import Combine

// MARK: - Battery-Safe Asynchronous Location Manager
public final class LocationManager: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()
    
    @Published public var location: CLLocationCoordinate2D?
    @Published public var locality: String?
    @Published public var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published public var isLocating: Bool = false
    
    public override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authorizationStatus = manager.authorizationStatus
        requestOneShotLocation()
    }
    
    public func requestOneShotLocation() {
        isLocating = true
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            isLocating = false
        @unknown default:
            isLocating = false
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    public func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
            manager.requestLocation()
        } else {
            isLocating = false
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        // Battery conservation: one-shot location only
        manager.stopUpdatingLocation()
        isLocating = false
        
        guard let loc = locations.first else { return }
        self.location = loc.coordinate
        
        // Reverse-geocode to retrieve locality name asynchronously
        geocoder.reverseGeocodeLocation(loc) { [weak self] placemarks, error in
            guard let self = self, error == nil, let place = placemarks?.first else { return }
            let name = [place.locality, place.administrativeArea].compactMap { $0 }.joined(separator: ", ")
            DispatchQueue.main.async {
                self.locality = name.isEmpty ? place.name : name
            }
        }
    }
    
    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Fail silently without blocking saving
        isLocating = false
        manager.stopUpdatingLocation()
    }
}
