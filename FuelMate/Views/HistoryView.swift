import SwiftUI
import MapKit

public enum LogSortOrder: String, CaseIterable, Identifiable {
    case newest = "Newest"
    case oldest = "Oldest"
    case highestCost = "Highest Cost"
    case highestEfficiency = "Highest Economy"
    
    public var id: String { rawValue }
}

public struct HistoryView: View {
    @ObservedObject public var viewModel: FuelLogViewModel
    @ObservedObject private var settings = UnitSettings.shared
    
    @State private var searchText = ""
    @State private var sortOrder: LogSortOrder = .newest
    @State private var selectedBrandFilter: String = "All"
    @State private var showingAddSheet = false
    
    private var filterBrands: [String] {
        ["All"] + SriLankanEcosystem.stationBrands
    }
    
    public init(viewModel: FuelLogViewModel) {
        self.viewModel = viewModel
    }
    
    private var filteredAndSortedLogs: [FuelLog] {
        var result = viewModel.logs
        
        // Brand Filter
        if selectedBrandFilter != "All" {
            result = result.filter { log in
                let name = log.stationName ?? ""
                if selectedBrandFilter == "Other" {
                    let known = ["ceypetco", "ioc", "sinopec", "shell", "rm parks"]
                    return !known.contains { name.lowercased().contains($0) }
                }
                let cleanBrand = selectedBrandFilter.replacingOccurrences(of: " / RM Parks", with: "")
                return name.localizedCaseInsensitiveContains(cleanBrand) ||
                       (selectedBrandFilter.contains("Shell") && name.localizedCaseInsensitiveContains("Shell"))
            }
        }
        
        // Full-Text Search Filter
        if !searchText.isEmpty {
            result = result.filter { log in
                let station = log.stationName ?? ""
                let locality = log.locality ?? ""
                let fuel = log.fuelGrade ?? ""
                let notes = log.notes ?? ""
                return station.localizedCaseInsensitiveContains(searchText) ||
                       locality.localizedCaseInsensitiveContains(searchText) ||
                       fuel.localizedCaseInsensitiveContains(searchText) ||
                       notes.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Sort Order
        switch sortOrder {
        case .newest:
            result.sort { $0.date > $1.date }
        case .oldest:
            result.sort { $0.date < $1.date }
        case .highestCost:
            result.sort { $0.totalCost > $1.totalCost }
        case .highestEfficiency:
            result.sort { (viewModel.tripEfficiency(for: $0) ?? 0) > (viewModel.tripEfficiency(for: $1) ?? 0) }
        }
        
        return result
    }
    
    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Horizontal Brand Filter Carousel
                brandFilterCarousel
                
                Group {
                    if viewModel.logs.isEmpty {
                        // Empty State View
                        ContentUnavailableView(
                            "No Fuel Logs for \(viewModel.selectedVehicle?.name ?? "Vehicle")",
                            systemImage: "list.clipboard",
                            description: Text("Tap '+' to log your first fill-up or scan a fuel receipt.")
                        )
                    } else if filteredAndSortedLogs.isEmpty {
                        ContentUnavailableView(
                            "No Matching Logs",
                            systemImage: "magnifyingglass",
                            description: Text("No records match your search or brand filter. Try adjusting the query.")
                        )
                    } else {
                        List {
                            // Summary Section Header
                            Section {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(filteredAndSortedLogs.count) Entries • \(viewModel.selectedVehicle?.name ?? "")")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                        Text(settings.formatCurrency(filteredAndSortedLogs.reduce(0.0) { $0 + $1.totalCost }))
                                            .font(.title3)
                                            .bold()
                                    }
                                    Spacer()
                                    Picker("Sort", selection: $sortOrder) {
                                        ForEach(LogSortOrder.allCases) { order in
                                            Text(order.rawValue).tag(order)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                }
                                .padding(.vertical, 2)
                            }
                            
                            // Grouped Sections by Month & Year
                            let monthGroups = viewModel.groupedLogs(from: filteredAndSortedLogs)
                            ForEach(monthGroups) { group in
                                Section {
                                    ForEach(group.logs) { log in
                                        NavigationLink(destination: LogDetailView(log: log, viewModel: viewModel)) {
                                            FuelLogRowView(log: log, viewModel: viewModel)
                                        }
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button(role: .destructive) {
                                                Haptics.medium()
                                                viewModel.deleteLog(log)
                                            } label: {
                                                Label("Delete", systemImage: "trash")
                                            }
                                        }
                                    }
                                } header: {
                                    HStack {
                                        Text(group.title)
                                            .font(.subheadline)
                                            .fontWeight(.bold)
                                        Spacer()
                                        Text("\(settings.formatCurrency(group.totalCost)) • \(settings.formatVolume(group.totalVolume))")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                    }
                                    .textCase(nil)
                                }
                            }
                        }
                        .listStyle(.insetGrouped)
                    }
                }
            }
            .background(AppTheme.groupedBackground.ignoresSafeArea())
            .refreshable {
                Haptics.light()
                viewModel.fetchLogs()
            }
            .navigationTitle("Fuel History")
            .searchable(text: $searchText, prompt: "Search station, city, fuel grade, notes")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !viewModel.logs.isEmpty {
                        ShareLink(
                            item: settings.exportCSV(logs: viewModel.logs, vehicleName: viewModel.selectedVehicle?.name),
                            subject: Text("FuelMate Logs Export"),
                            message: Text("Exported FuelMate vehicle logs.")
                        ) {
                            Label("Export CSV", systemImage: "square.and.arrow.up")
                        }
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        Haptics.medium()
                        showingAddSheet = true
                    }) {
                        Label("Add Fill-Up", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddLogView(viewModel: viewModel)
            }
        }
    }
    
    // MARK: - Brand Filter Carousel
    private var brandFilterCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filterBrands, id: \.self) { brand in
                    Button(action: {
                        Haptics.selection()
                        selectedBrandFilter = brand
                    }) {
                        Text(brand)
                            .font(.caption)
                            .fontWeight(selectedBrandFilter == brand ? .bold : .medium)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(selectedBrandFilter == brand ? Color(red: 0.0, green: 0.72, blue: 0.83) : Color(uiColor: .secondarySystemGroupedBackground))
                            .foregroundColor(selectedBrandFilter == brand ? .white : .primary)
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
    }
}

// MARK: - Fuel Log Row View
public struct FuelLogRowView: View {
    public let log: FuelLog
    public let viewModel: FuelLogViewModel
    @ObservedObject private var settings = UnitSettings.shared
    
    public var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppTheme.stationColor(for: log.stationName).opacity(0.14))
                    .frame(width: 42, height: 42)
                Image(systemName: "fuelpump.fill")
                    .foregroundColor(AppTheme.stationColor(for: log.stationName))
                    .font(.subheadline)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(log.stationName ?? "Fuel Station")
                        .font(.system(.body, weight: .semibold))
                    
                    let condition = TripCondition(rawValue: log.effectiveTripType) ?? .city
                    Text(condition.rawValue)
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(condition.badgeColor.opacity(0.15))
                        .foregroundColor(condition.badgeColor)
                        .clipShape(Capsule())
                    
                    if log.hasValidLocation {
                        Image(systemName: "location.fill")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack(spacing: 6) {
                    Text(log.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let fuel = log.fuelGrade {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(fuel)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if let dist = viewModel.tripDistance(for: log) {
                    Text("+\(settings.formatDistance(dist)) trip")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 3) {
                Text(settings.formatCurrency(log.totalCost))
                    .font(.system(.body, design: .rounded, weight: .bold))
                
                Text(settings.formatVolume(log.volume))
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let eff = viewModel.tripEfficiency(for: log) {
                    Text(settings.formatEfficiency(eff))
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.green.opacity(0.15))
                        .foregroundColor(.green)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Rich Log Detail View (Apple Maps Integration)
public struct LogDetailView: View {
    @Environment(\.dismiss) private var dismiss
    public let log: FuelLog
    public let viewModel: FuelLogViewModel
    @ObservedObject private var settings = UnitSettings.shared
    @State private var showingDeleteAlert = false
    
    public init(log: FuelLog, viewModel: FuelLogViewModel) {
        self.log = log
        self.viewModel = viewModel
    }
    
    public var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Apple Maps Integration (Fallback if coordinates == 0.0)
                if log.hasValidLocation {
                    Map(initialPosition: .region(MKCoordinateRegion(
                        center: CLLocationCoordinate2D(latitude: log.latitude, longitude: log.longitude),
                        span: MKCoordinateSpan(latitudeDelta: 0.015, longitudeDelta: 0.015)
                    ))) {
                        Marker(log.stationName ?? "Fuel Station", coordinate: CLLocationCoordinate2D(latitude: log.latitude, longitude: log.longitude))
                            .tint(AppTheme.stationColor(for: log.stationName))
                    }
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )
                }
                
                // Primary Cost Card
                VStack(spacing: 6) {
                    Text("Total Fill-Up Cost")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(settings.formatCurrency(log.totalCost))
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text(log.date.formatted(date: .complete, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let locality = log.locality, !locality.isEmpty {
                        Label(locality, systemImage: "mappin.and.ellipse")
                            .font(.caption2)
                            .foregroundColor(.blue)
                            .padding(.top, 2)
                    }
                }
                .frame(maxWidth: .infinity)
                .modernCard(padding: 20)
                
                // Metric Tiles
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                    DetailMetricTile(
                        title: "Fuel Volume",
                        value: settings.formatVolume(log.volume),
                        icon: "fuelpump.fill",
                        color: .orange
                    )
                    
                    DetailMetricTile(
                        title: "Unit Price",
                        value: settings.formatUnitPrice(log.unitPrice),
                        icon: "tag.fill",
                        color: .blue
                    )
                    
                    DetailMetricTile(
                        title: "Odometer",
                        value: settings.formatDistance(log.odometer),
                        icon: "speedometer",
                        color: .purple
                    )
                    
                    if let trip = viewModel.tripDistance(for: log) {
                        DetailMetricTile(
                            title: "Trip Distance",
                            value: settings.formatDistance(trip),
                            icon: "arrow.triangle.swap",
                            color: .green
                        )
                    } else {
                        DetailMetricTile(
                            title: "Trip Distance",
                            value: "Base Entry",
                            icon: "arrow.triangle.swap",
                            color: .gray
                        )
                    }
                    
                    if let eff = viewModel.tripEfficiency(for: log) {
                        DetailMetricTile(
                            title: "Calculated \(settings.unitSystem.efficiencyUnit)",
                            value: settings.formatEfficiency(eff),
                            icon: "gauge.with.dots.needle.bottom.50percent",
                            color: .green
                        )
                    }
                    
                    DetailMetricTile(
                        title: "Fuel Grade",
                        value: log.fuelGrade ?? "Petrol Octane 92",
                        icon: "drop.fill",
                        color: .teal
                    )
                    
                    let cond = TripCondition(rawValue: log.effectiveTripType) ?? .city
                    DetailMetricTile(
                        title: "Trip Condition",
                        value: cond.rawValue,
                        icon: cond.iconName,
                        color: cond.badgeColor
                    )
                }
                
                // Driving Notes Card
                if let notes = log.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Driving Notes", systemImage: "note.text")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(notes)
                            .font(.body)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .modernCard()
                }
                
                // Delete Button
                Button(role: .destructive, action: {
                    showingDeleteAlert = true
                }) {
                    Label("Delete Fuel Record", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)
                .padding(.top, 10)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
        .background(AppTheme.groupedBackground.ignoresSafeArea())
        .navigationTitle(log.stationName ?? "Fill-Up Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                ShareLink(
                    item: "FuelMate: \(log.stationName ?? "Fuel Stop") on \(log.date.formatted(date: .abbreviated, time: .omitted)) — Spent \(settings.formatCurrency(log.totalCost)) for \(settings.formatVolume(log.volume)) (\(settings.formatUnitPrice(log.unitPrice)))"
                ) {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
        .alert("Delete Fuel Log?", isPresented: $showingDeleteAlert) {
            Button("Delete", role: .destructive) {
                Haptics.medium()
                viewModel.deleteLog(log)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action cannot be undone.")
        }
    }
}

// MARK: - Detail Metric Tile
public struct DetailMetricTile: View {
    public let title: String
    public let value: String
    public let icon: String
    public let color: Color
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.system(.body, design: .rounded, weight: .bold))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modernCard(padding: 12)
    }
}
