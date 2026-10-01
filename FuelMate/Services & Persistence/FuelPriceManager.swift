import SwiftUI

// MARK: - Dynamic Fuel Price Engine (Sri Lankan Market Rates)
public final class FuelPriceManager: ObservableObject {
    public static let shared = FuelPriceManager()
    
    // MARK: - Storage Keys
    public static let keyPetrol92 = "price_petrol_92"
    public static let keyPetrol95Premium = "price_petrol_95_premium"
    public static let keyPetrol95Euro4 = "price_petrol_95_euro4"
    public static let keyXtraPremiumEuro3 = "price_xtrapremium_euro3"
    public static let keyAutoDiesel = "price_auto_diesel"
    public static let keySuperDieselEuro4 = "price_super_diesel_euro4"
    
    // MARK: - AppStorage Live Market Fuel Prices (October 2026 Sri Lankan Rates)
    @AppStorage(keyPetrol92) public var petrol92: Double = 414.0 {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage(keyPetrol95Premium) public var petrol95Premium: Double = 450.0 {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage(keyPetrol95Euro4) public var petrol95Euro4: Double = 440.0 {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage(keyXtraPremiumEuro3) public var xtraPremiumEuro3: Double = 445.0 {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage(keyAutoDiesel) public var autoDiesel: Double = 392.0 {
        didSet { objectWillChange.send() }
    }
    
    @AppStorage(keySuperDieselEuro4) public var superDieselEuro4: Double = 435.0 {
        didSet { objectWillChange.send() }
    }
    
    public init() {}
    
    // MARK: - Fuel Variety Metadata Definition
    public struct VarietyEntry: Identifiable {
        public var id: String { gradeName }
        public let gradeName: String
        public let shortLabel: String
        public let fuelType: String // "Petrol" or "Diesel"
        public let defaultPrice: Double
    }
    
    public static let varieties: [VarietyEntry] = [
        VarietyEntry(
            gradeName: "Petrol Octane 92",
            shortLabel: "Octane 92",
            fuelType: "Petrol",
            defaultPrice: 414.0
        ),
        VarietyEntry(
            gradeName: "Petrol Octane 95 (Premium)",
            shortLabel: "Octane 95 Premium",
            fuelType: "Petrol",
            defaultPrice: 450.0
        ),
        VarietyEntry(
            gradeName: "Petrol Octane 95 (Euro 4)",
            shortLabel: "Octane 95 Euro 4",
            fuelType: "Petrol",
            defaultPrice: 440.0
        ),
        VarietyEntry(
            gradeName: "Petrol XtraPremium Euro 3",
            shortLabel: "XtraPremium Euro 3",
            fuelType: "Petrol",
            defaultPrice: 445.0
        ),
        VarietyEntry(
            gradeName: "Lanka Auto Diesel",
            shortLabel: "Auto Diesel",
            fuelType: "Diesel",
            defaultPrice: 392.0
        ),
        VarietyEntry(
            gradeName: "Lanka Super Diesel 4 Star (Euro 4)",
            shortLabel: "Super Diesel 4 Star",
            fuelType: "Diesel",
            defaultPrice: 435.0
        )
    ]
    
    // MARK: - Price Lookup Engine
    public func getPrice(for grade: String) -> Double {
        let clean = grade.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        // Exact and fuzzy match checks
        if clean.contains("xtrapremium") || clean.contains("extra premium") {
            return xtraPremiumEuro3
        } else if clean.contains("95") && (clean.contains("premium") || clean.contains("lioc")) {
            return petrol95Premium
        } else if clean.contains("95") {
            return petrol95Euro4
        } else if clean.contains("92") {
            return petrol92
        } else if clean.contains("super diesel") || clean.contains("4 star") {
            return superDieselEuro4
        } else if clean.contains("diesel") {
            return autoDiesel
        }
        
        return petrol92 // Safe default
    }
    
    // MARK: - Direct Update Helper
    public func updatePrice(for grade: String, price: Double) {
        let safePrice = max(1.0, price)
        let clean = grade.lowercased()
        
        if clean.contains("xtrapremium") || clean.contains("extra premium") {
            xtraPremiumEuro3 = safePrice
        } else if clean.contains("95") && clean.contains("premium") {
            petrol95Premium = safePrice
        } else if clean.contains("95") {
            petrol95Euro4 = safePrice
        } else if clean.contains("92") {
            petrol92 = safePrice
        } else if clean.contains("super diesel") || clean.contains("4 star") {
            superDieselEuro4 = safePrice
        } else if clean.contains("diesel") {
            autoDiesel = safePrice
        }
    }
    
    // MARK: - Reset to Market Defaults
    public func resetToDefaults() {
        petrol92 = 414.0
        petrol95Premium = 450.0
        petrol95Euro4 = 440.0
        xtraPremiumEuro3 = 445.0
        autoDiesel = 392.0
        superDieselEuro4 = 435.0
    }
}
