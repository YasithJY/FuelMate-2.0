import SwiftUI

// MARK: - Sri Lankan Automotive Ecosystem Constants
public enum SriLankanEcosystem {
    public static let fuelGrades = [
        "Petrol 92 Octane",
        "Petrol 95 Octane",
        "Auto Diesel",
        "Super Diesel (Euro 4)",
        "Kerosene"
    ]
    
    public static let stationBrands = [
        "Ceypetco",
        "Lanka IOC",
        "Sinopec",
        "Shell / RM Parks",
        "Other"
    ]
    
    public static let vehicleTypes = [
        "Car",
        "Motorcycle",
        "SUV",
        "Van",
        "Three-Wheeler"
    ]
    
    public static let vehicleTypeIcons: [String: String] = [
        "Car": "car.side.fill",
        "Motorcycle": "motorcycle.fill",
        "Motorbike": "motorcycle.fill",
        "Motor Bicycle": "motorcycle.fill",
        "Bicycle": "bicycle",
        "SUV": "suv.side.fill",
        "Van": "box.truck.fill",
        "Three-Wheeler": "car.fill"
    ]
}

// MARK: - Dynamic Automotive Design System (Light & Dark Mode)
public enum AppTheme {
    // Primary Automotive Tint: Dynamic Teal/Cyan-to-Emerald gradient
    public static let primaryGradient = LinearGradient(
        colors: [
            Color(red: 0.0, green: 0.72, blue: 0.83), // Cyan / Teal
            Color(red: 0.1, green: 0.80, blue: 0.55)  // Emerald
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Emerald Success Gradient
    public static let emeraldGradient = LinearGradient(
        colors: [
            Color(red: 0.05, green: 0.75, blue: 0.45),
            Color(red: 0.15, green: 0.85, blue: 0.58)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Amber Alert Gradient
    public static let amberGradient = LinearGradient(
        colors: [
            Color(uiColor: .systemOrange),
            Color(uiColor: .systemYellow)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    // Crimson Error / Validation Tint
    public static let errorColor = Color(uiColor: .systemRed)
    public static let warningColor = Color(uiColor: .systemOrange)
    public static let successColor = Color(uiColor: .systemGreen)
    
    // Semantic System Backgrounds
    public static let primaryBackground = Color(uiColor: .systemBackground)
    public static let groupedBackground = Color(uiColor: .systemGroupedBackground)
    public static let secondaryCardBackground = Color(uiColor: .secondarySystemGroupedBackground)
    
    // Brand Accent Color Matcher for Sri Lankan & Global Gas Stations
    public static func stationColor(for name: String?) -> Color {
        guard let name = name?.lowercased() else { return Color(red: 0.0, green: 0.72, blue: 0.83) }
        if name.contains("ceypetco") || name.contains("ceylon petroleum") {
            return Color(red: 0.0, green: 0.42, blue: 0.82) // Ceypetco Blue
        }
        if name.contains("lioc") || name.contains("ioc") || name.contains("lanka ioc") {
            return Color(red: 0.96, green: 0.45, blue: 0.10) // Lanka IOC Orange
        }
        if name.contains("sinopec") {
            return Color(red: 0.86, green: 0.12, blue: 0.15) // Sinopec Crimson
        }
        if name.contains("shell") || name.contains("rm parks") {
            return Color(red: 0.95, green: 0.72, blue: 0.05) // Shell Gold
        }
        if name.contains("chevron") || name.contains("caltex") {
            return Color(red: 0.0, green: 0.35, blue: 0.70)
        }
        return Color(red: 0.0, green: 0.72, blue: 0.83)
    }
}

// MARK: - Modern Responsive Card View Modifier
public struct ModernCardModifier: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme
    public var padding: CGFloat = 16
    public var cornerRadius: CGFloat = 18
    public var useMaterial: Bool = false
    
    public func body(content: Content) -> some View {
        content
            .padding(padding)
            .background {
                if useMaterial {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                } else {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
            .shadow(
                color: Color.black.opacity(colorScheme == .dark ? 0.30 : 0.05),
                radius: 8,
                x: 0,
                y: 4
            )
    }
}

public extension View {
    func modernCard(padding: CGFloat = 16, cornerRadius: CGFloat = 18, useMaterial: Bool = false) -> some View {
        self.modifier(ModernCardModifier(padding: padding, cornerRadius: cornerRadius, useMaterial: useMaterial))
    }
    
    func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Tactile Haptic Engine
public enum Haptics {
    public static func light() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
    
    public static func medium() {
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }
    
    public static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }
    
    public static func error() {
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
    
    public static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
