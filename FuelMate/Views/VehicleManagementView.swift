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
                            if viewModel.vehicles.count > 1 {
                                Button(role: .destructive) {
                                    vehicleToDelete = vehicle
                                    showingDeleteAlert = true
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
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
                        }
                        
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("\(vehicle.fuelLogs.count) fill-ups")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(red: 0.0, green: 0.72, blue: 0.83))
                        .font(.title3)
                } else {
                    Button(action: onEdit) {
                        Image(systemName: "ellipsis")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .padding(8)
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
    
    public init(viewModel: FuelLogViewModel, vehicleToEdit: Vehicle? = nil) {
        self.viewModel = viewModel
        self.vehicleToEdit = vehicleToEdit
        
        if let v = vehicleToEdit {
            _name = State(initialValue: v.name)
            _plateNumber = State(initialValue: v.plateNumber ?? "")
            _vehicleType = State(initialValue: v.vehicleType)
            _tankCapacity = State(initialValue: String(format: "%.0f", v.tankCapacity))
            _initialOdometer = State(initialValue: String(format: "%.0f", v.initialOdometer))
        }
    }
    
    private var isFormValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
                    header: Text("Capacity & Mileage"),
                    footer: Text("Initial odometer establishes the baseline distance for trip economy calculations.")
                ) {
                    HStack {
                        Text("Tank Capacity (Liters)")
                        Spacer()
                        TextField("45", text: $tankCapacity)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                    
                    HStack {
                        Text("Initial Odometer (km)")
                        Spacer()
                        TextField("0", text: $initialOdometer)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
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
            }
        }
    }
    
    private func saveVehicle() {
        let capacity = Double(tankCapacity.replacingOccurrences(of: ",", with: ".")) ?? 45.0
        let odo = Double(initialOdometer.replacingOccurrences(of: ",", with: ".")) ?? 0.0
        
        if let existing = vehicleToEdit {
            viewModel.updateVehicle(
                existing,
                name: name,
                plateNumber: plateNumber.isEmpty ? nil : plateNumber,
                vehicleType: vehicleType,
                tankCapacity: capacity,
                initialOdometer: odo
            )
        } else {
            viewModel.addVehicle(
                name: name,
                plateNumber: plateNumber.isEmpty ? nil : plateNumber,
                vehicleType: vehicleType,
                tankCapacity: capacity,
                initialOdometer: odo
            )
        }
        Haptics.success()
        dismiss()
    }
}
