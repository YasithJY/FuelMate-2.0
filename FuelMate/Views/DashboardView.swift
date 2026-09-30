import SwiftUI
import Charts

public struct DashboardView: View {
    @ObservedObject public var viewModel: FuelLogViewModel
    @ObservedObject private var settings = UnitSettings.shared
    @Binding public var selectedTab: Int
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    @State private var showingAddSheet = false
    @State private var showingScannerSheet = false
    @State private var showingVehicleSheet = false
    @State private var animateRing = false
    
    public init(viewModel: FuelLogViewModel, selectedTab: Binding<Int>) {
        self.viewModel = viewModel
        self._selectedTab = selectedTab
    }
    
    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    // MARK: - Vehicle Profile Status Banner
                    vehicleProfileBanner
                    
                    // MARK: - Quick Action Bar
                    quickActionBar
                    
                    // MARK: - Responsive Main Content
                    if isRegularWidth {
                        HStack(alignment: .top, spacing: 20) {
                            efficiencyGaugeCard
                                .frame(maxWidth: 420)
                            
                            VStack(spacing: 16) {
                                kpiGridSection
                                if viewModel.efficiencyTrend.count > 1 {
                                    sparklineChartSection
                                }
                            }
                        }
                    } else {
                        efficiencyGaugeCard
                        kpiGridSection
                        if viewModel.efficiencyTrend.count > 1 {
                            sparklineChartSection
                        }
                    }
                    
                    // MARK: - Recent Fill-ups (Top 3)
                    recentFillUpsSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 36)
            }
            .background(AppTheme.groupedBackground.ignoresSafeArea())
            .refreshable {
                Haptics.light()
                viewModel.fetchLogs()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                // Top-Bar Leading: Multi-Vehicle Selector Dropdown Menu
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Section("Switch Vehicle") {
                            ForEach(viewModel.vehicles) { vehicle in
                                Button(action: {
                                    Haptics.selection()
                                    viewModel.selectVehicle(vehicle)
                                }) {
                                    HStack {
                                        Text(vehicle.displayName)
                                        if viewModel.selectedVehicle?.id == vehicle.id {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        }
                        
                        Divider()
                        
                        Button(action: {
                            showingVehicleSheet = true
                        }) {
                            Label("Manage Vehicles", systemImage: "gearshape.2")
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: viewModel.selectedVehicle?.iconName ?? "car.side.fill")
                                .foregroundColor(Color(red: 0.0, green: 0.72, blue: 0.83))
                            Text(viewModel.selectedVehicle?.name ?? "Select Vehicle")
                                .font(.headline)
                                .foregroundColor(.primary)
                            Image(systemName: "chevron.down.circle.fill")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Color.primary.opacity(0.04))
                        .clipShape(Capsule())
                    }
                }
                
                // Top-Bar Trailing: Quick Add Fill-Up
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        Haptics.medium()
                        showingAddSheet = true
                    }) {
                        Image(systemName: "plus")
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .padding(8)
                            .background(AppTheme.primaryGradient)
                            .foregroundColor(.white)
                            .clipShape(Circle())
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddLogView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingScannerSheet) {
                ReceiptScannerView(viewModel: viewModel)
            }
            .sheet(isPresented: $showingVehicleSheet) {
                VehicleManagementView(viewModel: viewModel)
            }
            .onAppear {
                withAnimation(.spring(response: 1.0, dampingFraction: 0.75)) {
                    animateRing = true
                }
            }
        }
    }
    
    // MARK: - Vehicle Profile Banner
    private var vehicleProfileBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: viewModel.selectedVehicle?.iconName ?? "car.side.fill")
                .font(.title2)
                .foregroundStyle(AppTheme.primaryGradient)
                .frame(width: 44, height: 44)
                .background(Color.blue.opacity(0.12))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(viewModel.selectedVehicle?.name ?? "Active Vehicle")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    if let plate = viewModel.selectedVehicle?.plateNumber, !plate.isEmpty {
                        Text(plate)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.12))
                            .clipShape(Capsule())
                    }
                }
                
                HStack(spacing: 6) {
                    if let lastOdo = viewModel.latestLog?.odometer {
                        Text("Odo: \(settings.formatDistance(lastOdo))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else if let initOdo = viewModel.selectedVehicle?.initialOdometer, initOdo > 0 {
                        Text("Odo: \(settings.formatDistance(initOdo))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Text("Ready to track")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("•")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Target: \(String(format: "%.1f", settings.targetEfficiency)) \(settings.unitSystem.efficiencyUnit)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Goal Achievement Badge
            if viewModel.averageEfficiency > 0 {
                let ratio = viewModel.averageEfficiency / max(settings.targetEfficiency, 1.0)
                HStack(spacing: 4) {
                    Image(systemName: ratio >= 1.0 ? "arrow.up.right" : "arrow.down.right")
                    Text("\(Int(ratio * 100))%")
                }
                .font(.caption)
                .bold()
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(ratio >= 1.0 ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                .foregroundColor(ratio >= 1.0 ? .green : .orange)
                .clipShape(Capsule())
            }
        }
        .modernCard(padding: 12)
    }
    
    // MARK: - Quick Action Bar
    private var quickActionBar: some View {
        HStack(spacing: 12) {
            Button(action: {
                Haptics.medium()
                showingScannerSheet = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "doc.viewfinder.fill")
                        .font(.subheadline)
                    Text("Scan Receipt")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
                .foregroundColor(.primary)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(AppTheme.primaryGradient, lineWidth: 1.2)
                )
                .shadow(color: Color.black.opacity(0.04), radius: 4, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            
            Button(action: {
                Haptics.medium()
                showingAddSheet = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.subheadline)
                    Text("Add Fill-Up")
                        .font(.system(.subheadline, design: .rounded, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(AppTheme.primaryGradient)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .shadow(color: Color(red: 0.0, green: 0.72, blue: 0.83).opacity(0.3), radius: 6, x: 0, y: 3)
            }
            .buttonStyle(.plain)
        }
    }
    
    // MARK: - Animated Efficiency Gauge Card
    private var efficiencyGaugeCard: some View {
        let target = max(settings.targetEfficiency, 1.0)
        let efficiency = viewModel.averageEfficiency
        let normalizedProgress = efficiency > 0 ? min(efficiency / target, 1.0) : 0.0
        
        return VStack(spacing: 18) {
            ZStack {
                // Background Circular Track
                Circle()
                    .stroke(Color.secondary.opacity(0.15), style: StrokeStyle(lineWidth: 18, lineCap: .round))
                    .frame(width: 185, height: 185)
                
                // Dynamic Animated Progress Arc
                Circle()
                    .trim(from: 0, to: animateRing ? CGFloat(normalizedProgress) : 0)
                    .stroke(
                        efficiency >= target ? AppTheme.emeraldGradient : AppTheme.primaryGradient,
                        style: StrokeStyle(lineWidth: 18, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 185, height: 185)
                    .animation(.spring(response: 1.2, dampingFraction: 0.8), value: animateRing)
                
                VStack(spacing: 4) {
                    Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                        .font(.title3)
                        .foregroundStyle(efficiency >= target ? AppTheme.emeraldGradient : AppTheme.primaryGradient)
                    
                    if efficiency > 0 {
                        Text(String(format: "%.1f", efficiency))
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        
                        Text(settings.unitSystem.efficiencyUnit)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                    } else {
                        Text("--")
                            .font(.system(size: 38, weight: .bold, design: .rounded))
                            .foregroundColor(.secondary)
                        Text("No Data Yet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding(.top, 8)
            
            HStack(spacing: 8) {
                Label(
                    title: { Text("\(viewModel.logs.count) Fill-Ups").font(.caption).foregroundColor(.secondary) },
                    icon: { Image(systemName: "checkmark.seal.fill").foregroundColor(.blue).font(.caption) }
                )
                
                if let last = viewModel.latestLog, let eff = viewModel.tripEfficiency(for: last) {
                    Text("•")
                        .foregroundColor(.secondary)
                    Text("Latest: \(settings.formatEfficiency(eff))")
                        .font(.caption)
                        .foregroundColor(eff >= target ? .green : .blue)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .modernCard(padding: 18)
    }
    
    // MARK: - Responsive 2x2 KPI Grid
    private var kpiGridSection: some View {
        let columns: [GridItem] = [
            GridItem(.flexible(), spacing: 12),
            GridItem(.flexible(), spacing: 12)
        ]
        
        return LazyVGrid(columns: columns, spacing: 12) {
            DashboardKpiCard(
                title: "Total Spent",
                value: viewModel.logs.isEmpty ? "\(settings.currencySymbol) 0.00" : settings.formatCurrency(viewModel.totalSpent),
                subtitle: "Cumulative fuel spend",
                icon: "dollarsign.circle.fill",
                gradient: AppTheme.emeraldGradient
            )
            
            DashboardKpiCard(
                title: "Tracked Distance",
                value: viewModel.totalDistance > 0 ? settings.formatDistance(viewModel.totalDistance) : "- \(settings.unitSystem.distanceUnit)",
                subtitle: "Net odometer span",
                icon: "arrow.triangle.swap",
                gradient: AppTheme.primaryGradient
            )
            
            DashboardKpiCard(
                title: "Avg Fuel Price",
                value: viewModel.averageFuelPrice > 0 ? settings.formatUnitPrice(viewModel.averageFuelPrice) : "-",
                subtitle: "Per \(settings.unitSystem.volumeUnit)",
                icon: "fuelpump.fill",
                gradient: AppTheme.amberGradient
            )
            
            DashboardKpiCard(
                title: "Cost / \(settings.unitSystem.distanceUnit)",
                value: viewModel.costPerKm > 0 ? "\(settings.currencySymbol) \(String(format: "%.2f", viewModel.costPerKm))/\(settings.unitSystem.distanceUnit)" : "-",
                subtitle: "Operating cost",
                icon: "chart.line.uptrend.xyaxis",
                gradient: AppTheme.primaryGradient
            )
        }
    }
    
    // MARK: - Sparkline Curve Section
    private var sparklineChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Fuel Economy Trajectory", systemImage: "waveform.path.ecg")
                    .font(.headline)
                Spacer()
                Button(action: {
                    selectedTab = 2 // Switch to Analytics Tab
                }) {
                    HStack(spacing: 2) {
                        Text("View Analytics")
                        Image(systemName: "chevron.right")
                    }
                    .font(.subheadline)
                    .foregroundColor(.blue)
                }
            }
            
            Chart(viewModel.efficiencyTrend) { point in
                LineMark(
                    x: .value("Date", point.date),
                    y: .value("Efficiency", point.efficiency)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(AppTheme.primaryGradient)
                .lineStyle(StrokeStyle(lineWidth: 3))
                
                AreaMark(
                    x: .value("Date", point.date),
                    y: .value("Efficiency", point.efficiency)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color(red: 0.0, green: 0.72, blue: 0.83).opacity(0.3), Color.clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                
                PointMark(
                    x: .value("Date", point.date),
                    y: .value("Efficiency", point.efficiency)
                )
                .foregroundStyle(Color(red: 0.0, green: 0.72, blue: 0.83))
                .symbolSize(26)
            }
            .frame(height: 135)
            .chartYAxis {
                AxisMarks(position: .leading)
            }
        }
        .modernCard()
    }
    
    // MARK: - Recent Fill-ups (Top 3) Section
    private var recentFillUpsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Fill-Ups")
                    .font(.headline)
                Spacer()
                if !viewModel.logs.isEmpty {
                    Button(action: {
                        selectedTab = 1 // Switch to History Tab
                    }) {
                        Text("See All (\(viewModel.logs.count))")
                            .font(.subheadline)
                            .foregroundColor(.blue)
                    }
                }
            }
            
            if viewModel.logs.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "fuelpump.circle.fill")
                        .font(.system(size: 46))
                        .foregroundStyle(AppTheme.primaryGradient)
                    
                    Text("No Fuel Logs for \(viewModel.selectedVehicle?.name ?? "This Vehicle")")
                        .font(.headline)
                    
                    Text("Record your first fill-up or scan a receipt to immediately preview Sri Lankan fuel analytics.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    HStack(spacing: 12) {
                        Button(action: {
                            Haptics.medium()
                            showingAddSheet = true
                        }) {
                            Text("+ Record Fill-Up")
                                .bold()
                                .font(.subheadline)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 10)
                                .background(AppTheme.primaryGradient)
                                .foregroundColor(.white)
                                .clipShape(Capsule())
                        }
                        
                        Button(action: {
                            Haptics.medium()
                            showingScannerSheet = true
                        }) {
                            Label("Scan Receipt", systemImage: "doc.viewfinder.fill")
                                .bold()
                                .font(.subheadline)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.secondary.opacity(0.12))
                                .foregroundColor(.primary)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .modernCard()
            } else {
                ForEach(viewModel.logs.prefix(3)) { log in
                    NavigationLink(destination: LogDetailView(log: log, viewModel: viewModel)) {
                        RecentLogCard(log: log, viewModel: viewModel)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - KPI Card Component
public struct DashboardKpiCard: View {
    public let title: String
    public let value: String
    public let subtitle: String
    public let icon: String
    public let gradient: LinearGradient
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(gradient)
                    .padding(8)
                    .background(Color.primary.opacity(0.05))
                    .clipShape(Circle())
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fontWeight(.medium)
                
                Text(value)
                    .font(.system(.title3, design: .rounded, weight: .bold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.70)
                
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .modernCard(padding: 12)
    }
}

// MARK: - Recent Log Card Component
public struct RecentLogCard: View {
    public let log: FuelLog
    public let viewModel: FuelLogViewModel
    @ObservedObject private var settings = UnitSettings.shared
    
    public var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(AppTheme.stationColor(for: log.stationName).opacity(0.14))
                    .frame(width: 44, height: 44)
                Image(systemName: "fuelpump.fill")
                    .foregroundColor(AppTheme.stationColor(for: log.stationName))
                    .font(.subheadline)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(log.stationName ?? "Fuel Station")
                    .font(.system(.subheadline, weight: .semibold))
                    .foregroundColor(.primary)
                
                HStack(spacing: 6) {
                    Text(log.date.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let dist = viewModel.tripDistance(for: log) {
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("+\(settings.formatDistance(dist))")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 3) {
                Text(settings.formatCurrency(log.totalCost))
                    .font(.system(.subheadline, design: .rounded, weight: .bold))
                    .foregroundColor(.primary)
                
                HStack(spacing: 4) {
                    Text(settings.formatVolume(log.volume))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let eff = viewModel.tripEfficiency(for: log) {
                        Text("•")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(settings.formatEfficiency(eff))
                            .font(.caption2)
                            .bold()
                            .foregroundColor(.green)
                    }
                }
            }
            
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundColor(.secondary.opacity(0.4))
        }
        .modernCard(padding: 12)
    }
}
