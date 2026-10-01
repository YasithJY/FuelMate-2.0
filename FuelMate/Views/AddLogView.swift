import SwiftUI
import CoreLocation

public struct AddLogView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject public var viewModel: FuelLogViewModel
    @StateObject private var locationManager = LocationManager()
    @ObservedObject private var settings = UnitSettings.shared
    @ObservedObject private var priceManager = FuelPriceManager.shared
    
    private enum FormField: Hashable {
        case odometer, volume, totalCost, station, notes
    }
    
    @FocusState private var focusedField: FormField?
    
    @State private var odometer: String = ""
    @State private var volume: String = ""
    @State private var totalCost: String = ""
    @State private var stationName: String = "Ceypetco"
    @State private var fuelGrade: String = "Petrol Octane 92"
    @State private var tripType: String = "City"
    @State private var isFullTank: Bool = true
    @State private var date: Date = Date()
    @State private var notes: String = ""
    @State private var latitude: Double = 0.0
    @State private var longitude: Double = 0.0
    @State private var locality: String? = nil
    
    @State private var showingMapPicker = false
    @State private var saveErrorMessage: String? = nil
    @State private var isPrefilledFromReceipt: Bool = false
    
    public init(viewModel: FuelLogViewModel, prefilledData: ScannedReceiptData? = nil) {
        self.viewModel = viewModel
        
        if let data = prefilledData {
            _isPrefilledFromReceipt = State(initialValue: true)
            if let cost = data.totalCost {
                _totalCost = State(initialValue: String(format: "%.2f", cost))
            }
            if let vol = data.volume {
                _volume = State(initialValue: String(format: "%.2f", vol))
            }
            if let st = data.stationName {
                _stationName = State(initialValue: st)
            }
            if let gr = data.fuelGrade {
                _fuelGrade = State(initialValue: gr)
            }
        }
    }
    
    // MARK: - Safe Parsed Doubles
    private var parsedOdometer: Double? {
        Double(odometer.replacingOccurrences(of: ",", with: "."))
    }
    
    private var parsedVolume: Double? {
        Double(volume.replacingOccurrences(of: ",", with: "."))
    }
    
    private var parsedTotalCost: Double? {
        Double(totalCost.replacingOccurrences(of: ",", with: "."))
    }
    
    // Baseline previous odometer
    private var previousOdometer: Double? {
        if let lastOdo = viewModel.latestLog?.odometer {
            return lastOdo
        }
        if let initOdo = viewModel.selectedVehicle?.initialOdometer, initOdo > 0 {
            return initOdo
        }
        return nil
    }
    
    // Current Market Rate based on selected fuel grade
    private var currentUnitPrice: Double {
        priceManager.getPrice(for: fuelGrade)
    }
    
    // MARK: - Validation Computations
    private var isOdometerRegressed: Bool {
        guard let currentOdo = parsedOdometer, let prevOdo = previousOdometer else {
            return false
        }
        return currentOdo <= prevOdo
    }
    
    private var odometerErrorMessage: String? {
        guard let currentOdo = parsedOdometer else {
            if !odometer.isEmpty {
                return "Please enter a valid numeric odometer reading."
            }
            return nil
        }
        
        if currentOdo <= 0 {
            return "Odometer must be strictly greater than 0."
        }
        
        if let prevOdo = previousOdometer, currentOdo <= prevOdo {
            return "Odometer must be higher than previous (\(settings.formatDistance(prevOdo)))."
        }
        return nil
    }
    
    private var isFormValid: Bool {
        guard viewModel.selectedVehicle != nil else { return false }
        guard let odo = parsedOdometer, odo > 0,
              let vol = parsedVolume, vol > 0,
              let cost = parsedTotalCost, cost > 0,
              !isOdometerRegressed else {
            return false
        }
        return true
    }
    
    // Live calculated unit price
    private var effectiveUnitPrice: Double {
        if let vol = parsedVolume, let cost = parsedTotalCost, vol > 0 {
            let p = cost / vol
            if p.isFinite && p > 0 { return p }
        }
        return currentUnitPrice
    }
    
    // Live calculated trip distance
    private var calculatedTripDistance: Double? {
        guard let currentOdo = parsedOdometer, let prevOdo = previousOdometer else { return nil }
        let diff = currentOdo - prevOdo
        return diff > 0 ? diff : nil
    }
    
    // Live calculated trip efficiency
    private var calculatedTripEfficiency: Double? {
        guard let dist = calculatedTripDistance, let vol = parsedVolume, vol > 0 else { return nil }
        let eff = dist / vol
        return eff.isFinite && eff > 0 ? eff : nil
    }
    
    public var body: some View {
        NavigationStack {
            Form {
                // MARK: - Vehicle Warning
                if viewModel.selectedVehicle == nil {
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("No Vehicle Selected")
                                    .font(.subheadline)
                                    .bold()
                                Text("Please register a vehicle before recording a fuel log.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                
                // MARK: - Prefilled Scanner Notice
                if isPrefilledFromReceipt {
                    Section {
                        HStack(spacing: 10) {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundColor(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Receipt OCR Data Loaded")
                                    .font(.subheadline)
                                    .bold()
                                Text("Values auto-populated from receipt. Please verify and enter odometer.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                
                // MARK: - Section 1: Trip Type Driving Condition
                Section(
                    header: Text("Trip Driving Condition"),
                    footer: Text("Categorize driving for this fuel load to benchmark against your City or Highway consumption targets.")
                ) {
                    Picker("Trip Type", selection: $tripType) {
                        ForEach(TripCondition.allCases) { condition in
                            Text(condition.rawValue).tag(condition.rawValue)
                        }
                    }
                    .pickerStyle(.segmented)
                    
                    HStack {
                        let condition = TripCondition(rawValue: tripType) ?? .city
                        Image(systemName: condition.iconName)
                            .foregroundColor(condition.badgeColor)
                        
                        Text("Active Benchmark:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        if let vehicle = viewModel.selectedVehicle {
                            if condition == .city {
                                Text("City Target: \(String(format: "%.1f", vehicle.effectiveCityConsumption)) km/L")
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(.orange)
                            } else if condition == .highway {
                                Text("Highway Target: \(String(format: "%.1f", vehicle.effectiveHighwayConsumption)) km/L")
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(.green)
                            } else {
                                let mixed = (vehicle.effectiveCityConsumption + vehicle.effectiveHighwayConsumption) / 2.0
                                Text("Mixed Benchmark: \(String(format: "%.1f", mixed)) km/L")
                                    .font(.caption)
                                    .bold()
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                
                // MARK: - Section 2: Fuel Grade & Market Unit Price
                Section(
                    header: Text("Fuel Grade & Live Market Rate"),
                    footer: Text("Unit price auto-syncs with the Fuel Price Manager. Changing Volume or Cost will auto-calculate the other.")
                ) {
                    Picker("Fuel Grade", selection: $fuelGrade) {
                        ForEach(SriLankanEcosystem.fuelGrades, id: \.self) { grade in
                            Text(grade).tag(grade)
                        }
                    }
                    .pickerStyle(.menu)
                    .onChange(of: fuelGrade) { _, newGrade in
                        recalculateOnGradeChange(newGrade: newGrade)
                    }
                    
                    HStack {
                        Label("Market Unit Price", systemImage: "tag.fill")
                            .font(.subheadline)
                        Spacer()
                        Text("\(settings.currencySymbol) \(String(format: "%.2f", currentUnitPrice)) / \(settings.unitSystem.volumeUnit)")
                            .font(.subheadline)
                            .bold()
                            .foregroundColor(Color(red: 0.0, green: 0.72, blue: 0.83))
                    }
                }
                
                // MARK: - Section 3: Fill-Up Metrics with Smart Auto-Calculation
                Section(
                    header: Text("Fill-Up Metrics"),
                    footer: Text("Odometer, Volume, and Total Cost must all be strictly greater than 0.")
                ) {
                    // Odometer Input
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Image(systemName: "speedometer")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            TextField("Odometer (\(settings.unitSystem.distanceUnit))", text: $odometer)
                                .keyboardType(.decimalPad)
                                .focused($focusedField, equals: .odometer)
                        }
                        
                        // Inline Red Error
                        if let error = odometerErrorMessage {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(AppTheme.errorColor)
                                .fontWeight(.semibold)
                                .padding(.leading, 32)
                                .transition(.opacity)
                        } else if let dist = calculatedTripDistance {
                            Text("+\(settings.formatDistance(dist)) trip distance")
                                .font(.caption)
                                .foregroundColor(.green)
                                .padding(.leading, 32)
                        } else if let prev = previousOdometer {
                            Text("Previous odometer: \(settings.formatDistance(prev))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.leading, 32)
                        }
                    }
                    
                    // Volume Input (Triggers Total Cost Auto-Calculation)
                    HStack {
                        Image(systemName: "fuelpump.fill")
                            .foregroundColor(.orange)
                            .frame(width: 24)
                        TextField("Volume (\(settings.unitSystem.volumeUnit))", text: $volume)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .volume)
                            .onChange(of: volume) { _, newVol in
                                if focusedField == .volume {
                                    handleVolumeInputChanged(newVol)
                                }
                            }
                    }
                    
                    // Total Cost Input (Triggers Volume Auto-Calculation)
                    HStack {
                        Image(systemName: "dollarsign.circle.fill")
                            .foregroundColor(.green)
                            .frame(width: 24)
                        TextField("Total Cost (\(settings.currencySymbol))", text: $totalCost)
                            .keyboardType(.decimalPad)
                            .focused($focusedField, equals: .totalCost)
                            .onChange(of: totalCost) { _, newCost in
                                if focusedField == .totalCost {
                                    handleTotalCostInputChanged(newCost)
                                }
                            }
                    }
                    
                    // Live Efficiency Preview
                    if let eff = calculatedTripEfficiency {
                        HStack {
                            Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                                .foregroundColor(.teal)
                                .frame(width: 24)
                            Text("Estimated Trip Economy:")
                                .font(.caption)
                            Spacer()
                            Text(settings.formatEfficiency(eff))
                                .font(.subheadline)
                                .bold()
                                .foregroundColor(.green)
                        }
                    }
                }
                
                // MARK: - Section 4: Condition & Date
                Section(header: Text("Condition & Timestamp")) {
                    Toggle(isOn: $isFullTank) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Filled to Full Tank")
                            Text("Required for exact consumption calculations between fuel stops.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    DatePicker("Date & Time", selection: $date, displayedComponents: [.date, .hourAndMinute])
                }
                
                // MARK: - Section 5: Station Brand & Map Selector
                Section(header: Text("Station Brand & Location")) {
                    HStack {
                        Image(systemName: "building.2.fill")
                            .foregroundColor(AppTheme.stationColor(for: stationName))
                            .frame(width: 24)
                        TextField("Station Brand (e.g. Ceypetco)", text: $stationName)
                            .focused($focusedField, equals: .station)
                    }
                    
                    // One-Tap Sri Lankan Brand Pills
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(SriLankanEcosystem.stationBrands, id: \.self) { brand in
                                Button(action: {
                                    Haptics.selection()
                                    stationName = brand
                                }) {
                                    Text(brand)
                                        .font(.caption)
                                        .fontWeight(stationName == brand ? .bold : .medium)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(stationName == brand ? AppTheme.stationColor(for: brand).opacity(0.18) : Color.secondary.opacity(0.10))
                                        .foregroundColor(stationName == brand ? AppTheme.stationColor(for: brand) : .primary)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    
                    // Map Search Button
                    Button(action: {
                        Haptics.medium()
                        showingMapPicker = true
                    }) {
                        HStack {
                            Image(systemName: "map.fill")
                                .foregroundColor(.blue)
                            Text("Search Station on Map")
                                .foregroundColor(.blue)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // GPS Locality Indicator
                    HStack {
                        Image(systemName: "location.fill")
                            .foregroundColor(.red)
                            .frame(width: 24)
                        
                        if let place = locality ?? locationManager.locality {
                            Text("📍 \(place)")
                                .font(.caption)
                                .foregroundColor(.primary)
                        } else if latitude != 0.0 && longitude != 0.0 {
                            Text(String(format: "GPS: %.4f, %.4f", latitude, longitude))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else if let loc = locationManager.location {
                            Text(String(format: "GPS: %.4f, %.4f", loc.latitude, loc.longitude))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        } else {
                            Text("Station location optional")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            Haptics.selection()
                            locationManager.requestOneShotLocation()
                        }) {
                            Image(systemName: "arrow.clockwise")
                                .font(.caption)
                                .foregroundColor(.blue)
                        }
                        .buttonStyle(.plain)
                    }
                }
                
                // MARK: - Section 6: Driving Notes
                Section(header: Text("Notes (Optional)")) {
                    TextField("Highway AC running, traffic delays, tire pressure checked, etc.", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                        .focused($focusedField, equals: .notes)
                }
                
                if let error = saveErrorMessage {
                    Section {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(AppTheme.errorColor)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("Log Fill-Up")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveLog()
                    }
                    .bold()
                    .disabled(!isFormValid)
                }
                
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                    }
                    .bold()
                }
            }
            .sheet(isPresented: $showingMapPicker) {
                StationPickerMapView(
                    stationName: $stationName,
                    latitude: $latitude,
                    longitude: $longitude,
                    locality: $locality
                )
            }
        }
    }
    
    // MARK: - Smart Auto-Calculation Handlers
    private func handleVolumeInputChanged(_ newVol: String) {
        guard let vol = Double(newVol.replacingOccurrences(of: ",", with: ".")), vol > 0 else { return }
        let rate = currentUnitPrice
        guard rate > 0 else { return }
        let calculatedCost = vol * rate
        totalCost = String(format: "%.2f", calculatedCost)
    }
    
    private func handleTotalCostInputChanged(_ newCost: String) {
        guard let cost = Double(newCost.replacingOccurrences(of: ",", with: ".")), cost > 0 else { return }
        let rate = currentUnitPrice
        guard rate > 0 else { return }
        let calculatedVol = cost / rate
        volume = String(format: "%.2f", calculatedVol)
    }
    
    private func recalculateOnGradeChange(newGrade: String) {
        let rate = priceManager.getPrice(for: newGrade)
        guard rate > 0 else { return }
        
        if let vol = parsedVolume, vol > 0 {
            let cost = vol * rate
            totalCost = String(format: "%.2f", cost)
        } else if let cost = parsedTotalCost, cost > 0 {
            let vol = cost / rate
            volume = String(format: "%.2f", vol)
        }
    }
    
    // MARK: - Save Log Action
    private func saveLog() {
        guard let odo = parsedOdometer,
              let vol = parsedVolume,
              let cost = parsedTotalCost else { return }
        
        let finalLat = latitude != 0.0 ? latitude : (locationManager.location?.latitude ?? 0.0)
        let finalLon = longitude != 0.0 ? longitude : (locationManager.location?.longitude ?? 0.0)
        let finalLocality = locality ?? locationManager.locality
        
        do {
            try viewModel.addLog(
                odometer: odo,
                volume: vol,
                totalCost: cost,
                stationName: stationName,
                latitude: finalLat,
                longitude: finalLon,
                locality: finalLocality,
                fuelGrade: fuelGrade,
                tripType: tripType,
                notes: notes,
                isFullTank: isFullTank,
                date: date
            )
            Haptics.success()
            dismiss()
        } catch {
            Haptics.error()
            saveErrorMessage = error.localizedDescription
        }
    }
}
