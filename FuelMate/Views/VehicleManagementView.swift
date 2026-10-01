import SwiftUI

public struct VehicleManagementView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject public var viewModel: FuelLogViewModel
    @ObservedObject private var settings = UnitSettings.shared
    
    @State private var showingAddSheet = false
    @State private var editingVehicle: Vehicle? = nil
    @State private var vehicleToDelete: Vehicle? = nil
    @State private var showingDeleteAlert = false
    
    public init(viewModel: FuelLogViewModel) {
        self.viewModel = viewModel
    }
    
    public var body: some View {
        NavigationStack {
            List {
                Section(
                    header: Text("Tracked Vehicles"),
                    footer: Text("Tap a vehicle to make it the active vehicle for Dashboard, Analytics, and Fuel History.")
                ) {
                    if viewModel.vehicles.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "car.2.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary)
                            Text("No Vehicles Registered")
                                .font(.headline)
                            Text("Add your vehicle to start logging fuel fill-ups and tracking consumption.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            Button(action: {
                                Haptics.medium()
                                showingAddSheet = true
                            }) {
                                Label("Add First Vehicle", systemImage: "plus")
                                    .bold()
                            }
                            .buttonStyle(.borderedProminent)
                            .padding(.top, 4)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 20)
                    } else {
                        ForEach(viewModel.vehicles) { vehicle in
                            VehicleRowView(
                                vehicle: vehicle,
                                isSelected: viewModel.selectedVehicle?.id == vehicle.id,
                                onSelect: {
                                    Haptics.selection()
                                    viewModel.selectVehicle(vehicle)
                                },
                                onEdit: {
                                    editingVehicle = vehicle
                                }
                            )
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    vehicleToDelete = vehicle
                                    showingDeleteAlert = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                
                                Button {
                                    editingVehicle = vehicle
                                } label: {
                                    Label("Edit", systemImage: "pencil")
                                }
                                .tint(.blue)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Vehicles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: {
                        Haptics.medium()
                        showingAddSheet = true
                    }) {
                        Label("Add Vehicle", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                VehicleEditorSheet(viewModel: viewModel)
            }
            .sheet(item: $editingVehicle) { vehicle in
                VehicleEditorSheet(viewModel: viewModel, vehicleToEdit: vehicle)
            }
            .alert("Delete Vehicle?", isPresented: $showingDeleteAlert) {
                Button("Delete", role: .destructive) {
                    if let toDelete = vehicleToDelete {
                        Haptics.medium()
                        viewModel.deleteVehicle(toDelete)
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Deleting this vehicle will also remove all its recorded fuel logs. This action cannot be undone.")
            }
        }
    }
}

// MARK: - Vehicle Row View
private struct VehicleRowView: View {
    let vehicle: Vehicle
    let isSelected: Bool
    let onSelect: () -> Void
    let onEdit: () -> Void
    @ObservedObject private var settings = UnitSettings.shared
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color(red: 0.0, green: 0.72, blue: 0.83).opacity(0.18) : Color.secondary.opacity(0.12))
                        .frame(width: 46, height: 46)
                    
                    Image(systemName: vehicle.iconName)
                        .foregroundColor(isSelected ? Color(red: 0.0, green: 0.72, blue: 0.83) : .secondary)
                        .font(.title3)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(vehicle.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if isSelected {
                            Text("Active")
                                .font(.caption2)
                                .bold()
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.15))
                                .foregroundColor(.green)
                                .clipShape(Capsule())
                        }
                    }
                    
                    HStack(spacing: 8) {
                        if let plate = vehicle.plateNumber, !plate.isEmpty {
                            Text(plate)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("•")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Text("\(vehicle.fuelLogs.count) logs")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    // Dual Baselines Display
                    HStack(spacing: 8) {
                        HStack(spacing: 3) {
                            Image(systemName: "building.2.crop.circle")
                                .font(.caption2)
                                .foregroundColor(.orange)
                            Text("City: \(String(format: "%.1f", vehicle.effectiveCityConsumption)) \(settings.unitSystem.efficiencyUnit)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Text("•")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        HStack(spacing: 3) {
                            Image(systemName: "road.lanes")
                                .font(.caption2)
                                .foregroundColor(.green)
                            Text("Hwy: \(String(format: "%.1f", vehicle.effectiveHighwayConsumption)) \(settings.unitSystem.efficiencyUnit)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.top, 2)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(red: 0.0, green: 0.72, blue: 0.83))
                        .font(.title3)
                } else {
                    Button(action: onEdit) {
                        Image(systemName: "pencil.circle")
                            .font(.title3)
                            .foregroundColor(.secondary)
                            .padding(4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Vehicle Editor Sheet (Add / Edit)
public struct VehicleEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject public var viewModel: FuelLogViewModel
    public var vehicleToEdit: Vehicle? = nil
    
    @State private var name: String = ""
    @State private var plateNumber: String = ""
    @State private var vehicleType: String = "Car"
    @State private var tankCapacity: String = "45"
    @State private var initialOdometer: String = "0"
    @State private var cityFuelConsumption: String = "10.0"
    @State private var highwayFuelConsumption: String = "15.0"
    
    public init(viewModel: FuelLogViewModel, vehicleToEdit: Vehicle? = nil) {
        self.viewModel = viewModel
        self.vehicleToEdit = vehicleToEdit
        
        if let v = vehicleToEdit {
            _name = State(initialValue: v.name)
            _plateNumber = State(initialValue: v.plateNumber ?? "")
            _vehicleType = State(initialValue: v.vehicleType)
            _tankCapacity = State(initialValue: String(format: "%.0f", v.tankCapacity))
            _initialOdometer = State(initialValue: String(format: "%.0f", v.initialOdometer))
            _cityFuelConsumption = State(initialValue: String(format: "%.1f", v.effectiveCityConsumption))
            _highwayFuelConsumption = State(initialValue: String(format: "%.1f", v.effectiveHighwayConsumption))
        } else {
            _cityFuelConsumption = State(initialValue: "10.0")
            _highwayFuelConsumption = State(initialValue: "15.0")
        }
    }
    
    private var parsedCityFuel: Double? {
        Double(cityFuelConsumption.replacingOccurrences(of: ",", with: "."))
    }
    
    private var parsedHighwayFuel: Double? {
        Double(highwayFuelConsumption.replacingOccurrences(of: ",", with: "."))
    }
    
    private var isCityFuelValid: Bool {
        guard let val = parsedCityFuel else { return false }
        return val > 0 && !val.isNaN && !val.isInfinite
    }
    
    private var isHighwayFuelValid: Bool {
        guard let val = parsedHighwayFuel else { return false }
        return val > 0 && !val.isNaN && !val.isInfinite
    }
    
    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        isCityFuelValid &&
        isHighwayFuelValid
    }
    
    public var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Vehicle Details")) {
                    TextField("Vehicle Name (e.g. Toyota Prius)", text: $name)
                    TextField("License Plate (e.g. WP CAB-2045)", text: $plateNumber)
                    
                    Picker("Vehicle Type", selection: $vehicleType) {
                        ForEach(SriLankanEcosystem.vehicleTypes, id: \.self) { type in
                            HStack {
                                Image(systemName: SriLankanEcosystem.vehicleTypeIcons[type] ?? "car.fill")
                                Text(type)
                            }
                            .tag(type)
                        }
                    }
                }
                
                Section(
                    header: Text("Target Consumption Baselines"),
                    footer: Text("Set your vehicle's expected fuel consumption. Both baselines must be strictly greater than 0 km/L.")
                ) {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Label("Target City Fuel Consumption (km/L)", systemImage: "building.2.crop.circle")
                                .foregroundColor(.primary)
                            Spacer()
                            TextField("10.0", text: $cityFuelConsumption)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }
                        
                        if !cityFuelConsumption.isEmpty && !isCityFuelValid {
                            Text("Target City Fuel Consumption must be strictly greater than 0.")
                                .font(.caption)
                                .foregroundColor(AppTheme.errorColor)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Label("Target Highway Fuel Consumption (km/L)", systemImage: "road.lanes")
                                .foregroundColor(.primary)
                            Spacer()
                            TextField("15.0", text: $highwayFuelConsumption)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }
                        
                        if !highwayFuelConsumption.isEmpty && !isHighwayFuelValid {
                            Text("Target Highway Fuel Consumption must be strictly greater than 0.")
                                .font(.caption)
                                .foregroundColor(AppTheme.errorColor)
                        }
                    }
                }
                
                Section(
                    header: Text("Capacity & Mileage"),
                    footer: Text("Initial odometer establishes the baseline distance for trip economy calculations.")
                ) {
                    HStack {
                        Text("Tank Capacity (Liters)")
                        Spacer()
                        TextField("45", text: $tankCapacity)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    
                    HStack {
                        Text("Initial Odometer (km)")
                        Spacer()
                        TextField("0", text: $initialOdometer)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle(vehicleToEdit == nil ? "Add Vehicle" : "Edit Vehicle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveVehicle()
                    }
                    .bold()
                    .disabled(!isFormValid)
                }
                
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        hideKeyboard()
                    }
                    .bold()
                }
            }
        }
    }
    
    private func saveVehicle() {
        guard isFormValid else { return }
        
        let capacity = Double(tankCapacity.replacingOccurrences(of: ",", with: ".")) ?? 45.0
        let odo = Double(initialOdometer.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        let city = parsedCityFuel ?? 10.0
        let highway = parsedHighwayFuel ?? 15.0
        
        if let existing = vehicleToEdit {
            viewModel.updateVehicle(
                existing,
                name: name,
                plateNumber: plateNumber.isEmpty ? nil : plateNumber,
                vehicleType: vehicleType,
                tankCapacity: capacity,
                initialOdometer: odo,
                cityFuelConsumption: city,
                highwayFuelConsumption: highway
            )
        } else {
            viewModel.addVehicle(
                name: name,
                plateNumber: plateNumber.isEmpty ? nil : plateNumber,
                vehicleType: vehicleType,
                tankCapacity: capacity,
                initialOdometer: odo,
                cityFuelConsumption: city,
                highwayFuelConsumption: highway
            )
        }
        Haptics.success()
        dismiss()
    }
}
