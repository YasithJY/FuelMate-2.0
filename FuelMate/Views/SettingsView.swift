import SwiftUI

public struct SettingsView: View {
    @ObservedObject public var viewModel: FuelLogViewModel
    @ObservedObject private var settings = UnitSettings.shared
    @ObservedObject private var priceManager = FuelPriceManager.shared
    
    @State private var showingResetAlert = false
    @State private var showingPriceResetAlert = false
    
    private let availableCurrencies = ["Rs.", "$", "€", "£", "₹", "AED", "SGD", "AUD"]
    
    public init(viewModel: FuelLogViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationStack {
            Form {
                // Section 1: Active Vehicle & Fleet Management
                Section(
                    header: Text("Vehicle Fleet"),
                    footer: Text("Manage multiple vehicles, baseline City/Highway consumption targets, and tank capacities.")
                ) {
                    NavigationLink(destination: VehicleManagementView(viewModel: viewModel)) {
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Color(red: 0.0, green: 0.72, blue: 0.83).opacity(0.15))
                                    .frame(width: 38, height: 38)
                                Image(systemName: viewModel.selectedVehicle?.iconName ?? "car.side.fill")
                                    .foregroundColor(Color(red: 0.0, green: 0.72, blue: 0.83))
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text(viewModel.selectedVehicle?.name ?? "No Vehicle Selected")
                                    .font(.headline)
                                Text(viewModel.selectedVehicle?.plateNumber ?? "Manage fleet")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Text("\(viewModel.vehicles.count) Vehicles")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    if let vehicle = viewModel.selectedVehicle {
                        HStack {
                            Image(systemName: "building.2.crop.circle")
                                .foregroundColor(.orange)
                                .frame(width: 24)
                            Text("City Baseline Target")
                            Spacer()
                            Text("\(String(format: "%.1f", vehicle.effectiveCityConsumption)) \(settings.unitSystem.efficiencyUnit)")
                                .bold()
                                .foregroundColor(.primary)
                        }
                        
                        HStack {
                            Image(systemName: "road.lanes")
                                .foregroundColor(.green)
                                .frame(width: 24)
                            Text("Highway Baseline Target")
                            Spacer()
                            Text("\(String(format: "%.1f", vehicle.effectiveHighwayConsumption)) \(settings.unitSystem.efficiencyUnit)")
                                .bold()
                                .foregroundColor(.primary)
                        }
                    }
                }
                
                // Section 2: Dedicated Current Fuel Prices (LKR/L)
                Section(
                    header: Text("Current Fuel Prices (LKR/L)"),
                    footer: Text("Live Sri Lankan market rates. Updating these prices immediately applies to unit price calculations and receipt audits in the Add Fill-Up sheet.")
                ) {
                    FuelPriceRow(
                        title: "Petrol Octane 92",
                        subtitle: "Standard Unleaded",
                        icon: "fuelpump.fill",
                        iconColor: .orange,
                        price: $priceManager.petrol92,
                        currencySymbol: settings.currencySymbol
                    )
                    
                    FuelPriceRow(
                        title: "Petrol Octane 95 (Premium)",
                        subtitle: "LIOC / Sinopec Premium",
                        icon: "fuelpump.fill",
                        iconColor: .blue,
                        price: $priceManager.petrol95Premium,
                        currencySymbol: settings.currencySymbol
                    )
                    
                    FuelPriceRow(
                        title: "Petrol Octane 95 (Euro 4)",
                        subtitle: "CPC Euro 4 Standard",
                        icon: "fuelpump.fill",
                        iconColor: .teal,
                        price: $priceManager.petrol95Euro4,
                        currencySymbol: settings.currencySymbol
                    )
                    
                    FuelPriceRow(
                        title: "Petrol XtraPremium Euro 3",
                        subtitle: "LIOC Additive Blend",
                        icon: "fuelpump.fill",
                        iconColor: .purple,
                        price: $priceManager.xtraPremiumEuro3,
                        currencySymbol: settings.currencySymbol
                    )
                    
                    FuelPriceRow(
                        title: "Lanka Auto Diesel",
                        subtitle: "Standard Diesel",
                        icon: "drop.fill",
                        iconColor: .gray,
                        price: $priceManager.autoDiesel,
                        currencySymbol: settings.currencySymbol
                    )
                    
                    FuelPriceRow(
                        title: "Lanka Super Diesel 4 Star (Euro 4)",
                        subtitle: "Low Sulfur Premium Diesel",
                        icon: "sparkles",
                        iconColor: .green,
                        price: $priceManager.superDieselEuro4,
                        currencySymbol: settings.currencySymbol
                    )
                    
                    Button(action: {
                        showingPriceResetAlert = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset Prices to October 2026 Rates")
                        }
                        .font(.footnote)
                        .foregroundColor(Color(red: 0.0, green: 0.72, blue: 0.83))
                    }
                }
                
                // Section 3: Units & Measurement
                Section(header: Text("Units & Measurement")) {
                    Picker("Unit System", selection: Binding(
                        get: { settings.unitSystem },
                        set: {
                            Haptics.selection()
                            settings.unitSystem = $0
                        }
                    )) {
                        ForEach(UnitSystem.allCases) { sys in
                            Text(sys.title).tag(sys)
                        }
                    }
                    .pickerStyle(.menu)
                    
                    HStack {
                        Text("Distance Unit")
                        Spacer()
                        Text(settings.unitSystem.distanceUnit)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Volume Unit")
                        Spacer()
                        Text(settings.unitSystem.volumeUnit)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Efficiency Metric")
                        Spacer()
                        Text(settings.unitSystem.efficiencyUnit)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Section 4: Currency & Localization
                Section(
                    header: Text("Currency"),
                    footer: Text("Defaults to Sri Lankan Rupee (Rs.). Instant toggle to international currencies.")
                ) {
                    Picker("Active Currency", selection: Binding(
                        get: { settings.currencySymbol },
                        set: {
                            Haptics.selection()
                            settings.currencySymbol = $0
                        }
                    )) {
                        ForEach(availableCurrencies, id: \.self) { curr in
                            Text(curr).tag(curr)
                        }
                    }
                    .pickerStyle(.menu)
                }
                
                // Section 5: Data Management & Export
                Section(
                    header: Text("Data Management & Export"),
                    footer: Text("Export your complete history as a standard RFC-4180 CSV file.")
                ) {
                    if !viewModel.logs.isEmpty {
                        ShareLink(
                            item: settings.exportCSV(logs: viewModel.logs, vehicleName: viewModel.selectedVehicle?.name),
                            subject: Text("FuelMate Logs Export"),
                            message: Text("Exported FuelMate vehicle logs.")
                        ) {
                            Label("Export Logs to CSV", systemImage: "arrow.up.doc.fill")
                                .foregroundColor(.blue)
                        }
                    } else {
                        Label("Export Logs to CSV (No Logs)", systemImage: "arrow.up.doc")
                            .foregroundColor(.secondary)
                    }
                    
                    Button(role: .destructive, action: {
                        showingResetAlert = true
                    }) {
                        Label("Clear All Records", systemImage: "trash")
                            .foregroundColor(AppTheme.errorColor)
                    }
                }
                
                // Section 6: Architecture & About
                Section(header: Text("About FuelMate")) {
                    HStack(spacing: 16) {
                        Image("AppLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 54, height: 54)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                            .shadow(color: Color.black.opacity(0.12), radius: 4, x: 0, y: 2)
                        
                        VStack(alignment: .leading, spacing: 3) {
                            Text("FuelMate 2.0")
                                .font(.headline)
                            Text("Vehicle Fuel & Expense Tracker")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("2.0.0 (Production-Grade)")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Architecture")
                        Spacer()
                        Text("SwiftUI + Core Data + Vision OCR")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Ecosystem")
                        Spacer()
                        Text("Sri Lanka Localized (LKR, km, L)")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        hideKeyboard()
                    }
                    .bold()
                }
            }
            .alert("Reset Fuel Prices?", isPresented: $showingPriceResetAlert) {
                Button("Reset to Defaults", role: .destructive) {
                    Haptics.medium()
                    priceManager.resetToDefaults()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This will restore default October 2026 Sri Lankan market rates (e.g. Petrol 92 at Rs. 414.00, Auto Diesel at Rs. 392.00).")
            }
            .alert("Clear All Records?", isPresented: $showingResetAlert) {
                Button("Clear Everything", role: .destructive) {
                    Haptics.medium()
                    viewModel.clearAllLogs()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to permanently erase all fuel records? This action cannot be undone.")
            }
        }
    }
}

// MARK: - Fuel Price Row Component
private struct FuelPriceRow: View {
    let title: String
    let subtitle: String?
    let icon: String
    let iconColor: Color
    @Binding var price: Double
    let currencySymbol: String
    
    @State private var textValue: String = ""
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                if let sub = subtitle {
                    Text(sub)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            HStack(spacing: 4) {
                Text(currencySymbol)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                TextField("Price", text: Binding(
                    get: {
                        if textValue.isEmpty {
                            return String(format: "%.2f", price)
                        }
                        return textValue
                    },
                    set: { newValue in
                        textValue = newValue
                        if let parsed = Double(newValue.replacingOccurrences(of: ",", with: ".")) {
                            price = max(0.0, parsed)
                        }
                    }
                ))
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 86)
                .padding(.vertical, 4)
                .padding(.horizontal, 6)
                .background(Color(uiColor: .tertiarySystemFill))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
        .onAppear {
            textValue = String(format: "%.2f", price)
        }
        .onChange(of: price) { _, newPrice in
            textValue = String(format: "%.2f", newPrice)
        }
    }
}
