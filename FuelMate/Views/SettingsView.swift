import SwiftUI

public struct SettingsView: View {
    @ObservedObject public var viewModel: FuelLogViewModel
    @ObservedObject private var settings = UnitSettings.shared
    
    @State private var showingResetAlert = false
    
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
                    footer: Text("Manage multiple vehicles, plate numbers, and baseline tank capacities.")
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
                    
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Image(systemName: "target")
                                .foregroundColor(.green)
                                .frame(width: 24)
                            Text("Target Economy")
                            Spacer()
                            Text("\(String(format: "%.1f", settings.targetEfficiency)) \(settings.unitSystem.efficiencyUnit)")
                                .bold()
                                .foregroundColor(.primary)
                        }
                        
                        Slider(
                            value: $settings.targetEfficiency,
                            in: 5...60,
                            step: 0.5
                        )
                        .tint(Color(red: 0.0, green: 0.72, blue: 0.83))
                    }
                }
                
                // Section 2: Units & Measurement
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
                
                // Section 3: Currency & Localization
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
                
                // Section 4: Data Management & Export
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
                
                // Section 5: Architecture & About
                Section(header: Text("About FuelMate")) {
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
