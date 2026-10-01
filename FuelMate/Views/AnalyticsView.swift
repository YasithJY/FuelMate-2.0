import SwiftUI
import Charts

public struct AnalyticsView: View {
    @ObservedObject public var viewModel: FuelLogViewModel
    @ObservedObject private var settings = UnitSettings.shared
    
    @State private var selectedTimeRange: AnalyticsTimeRange = .all
    @State private var rawSelectedDate: Date? = nil
    
    public init(viewModel: FuelLogViewModel) {
        self.viewModel = viewModel
    }
    
    private var filteredEfficiencyPoints: [EfficiencyPoint] {
        viewModel.efficiencyTrend(for: selectedTimeRange)
    }
    
    private var filteredMonthlySpends: [MonthlySpend] {
        viewModel.monthlySpendingTrend(for: selectedTimeRange)
    }
    
    // Interactive scrub point selector
    private var scrubbedPoint: EfficiencyPoint? {
        guard let date = rawSelectedDate else { return nil }
        return filteredEfficiencyPoints.min(by: {
            abs($0.date.timeIntervalSince(date)) < abs($1.date.timeIntervalSince(date))
        })
    }
    
    public var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    // Time-Range Segmented Picker (30D, 6M, 1Y, All)
                    Picker("Time Range", selection: $selectedTimeRange) {
                        ForEach(AnalyticsTimeRange.allCases) { range in
                            Text(range.rawValue).tag(range)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.top, 4)
                    
                    if viewModel.logs.count < 2 {
                        // Empty State View
                        ContentUnavailableView(
                            "Not Enough Data for Trends",
                            systemImage: "chart.xyaxis.line",
                            description: Text("Add at least 2 fill-up logs for \(viewModel.selectedVehicle?.name ?? "this vehicle") to generate Catmull-Rom fuel economy splines and expense charts.")
                        )
                        .padding(.top, 40)
                    } else {
                        // Chart 1: Catmull-Rom Fuel Economy Spline
                        economySplineCard
                        
                        // Chart 2: Monthly Expense Bar Chart
                        monthlyExpenseCard
                        
                        // Vehicle Highlights Grid
                        vehicleInsightsGrid
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 36)
            }
            .background(AppTheme.groupedBackground.ignoresSafeArea())
            .navigationTitle("Analytics")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Section("Active Vehicle") {
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
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: viewModel.selectedVehicle?.iconName ?? "car.side.fill")
                            Text(viewModel.selectedVehicle?.name ?? "Vehicle")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                        }
                        .foregroundColor(Color(red: 0.0, green: 0.72, blue: 0.83))
                    }
                }
            }
        }
    }
    
    // MARK: - Chart 1: Catmull-Rom Fuel Economy Spline
    private var economySplineCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Fuel Economy Trajectory")
                        .font(.headline)
                    Text("Catmull-Rom spline in \(settings.unitSystem.efficiencyUnit)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                
                // Scrubbed Point Callout
                if let pt = scrubbedPoint {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(settings.formatEfficiency(pt.efficiency))
                            .font(.system(.subheadline, design: .rounded, weight: .bold))
                            .foregroundColor(Color(red: 0.0, green: 0.72, blue: 0.83))
                        Text(pt.stationName)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            if filteredEfficiencyPoints.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.title3)
                        .foregroundColor(.secondary.opacity(0.6))
                    Text("Not enough data")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    Text("Requires 2+ full-tank fills in selected time window.")
                        .font(.caption2)
                        .foregroundColor(.secondary.opacity(0.8))
                }
                .frame(height: 200)
                .frame(maxWidth: .infinity, alignment: .center)
            } else {
                Chart {
                    ForEach(filteredEfficiencyPoints) { point in
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
                                colors: [Color(red: 0.0, green: 0.72, blue: 0.83).opacity(0.32), Color.clear],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        
                        PointMark(
                            x: .value("Date", point.date),
                            y: .value("Efficiency", point.efficiency)
                        )
                        .foregroundStyle(Color(red: 0.0, green: 0.72, blue: 0.83))
                        .symbolSize(rawSelectedDate != nil && scrubbedPoint?.id == point.id ? 72 : 32)
                    }
                    
                    // Dynamic Baseline Average Rule
                    if viewModel.averageEfficiency > 0 {
                        RuleMark(y: .value("Average", viewModel.averageEfficiency))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [5, 5]))
                            .foregroundStyle(Color.green)
                            .annotation(position: .bottom, alignment: .leading) {
                                Text("Avg: \(String(format: "%.1f", viewModel.averageEfficiency))")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                                    .padding(.leading, 4)
                            }
                    }
                    
                    // Interactive Scrub Tracker Rule
                    if let selected = scrubbedPoint {
                        RuleMark(x: .value("Selected Date", selected.date))
                            .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                            .foregroundStyle(Color.secondary.opacity(0.5))
                    }
                }
                .frame(height: 220)
                .chartXSelection(value: $rawSelectedDate)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
            }
        }
        .modernCard(padding: 16)
    }
    
    // MARK: - Chart 2: Monthly Expense Bar Chart
    private var monthlyExpenseCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Monthly Fuel Expenses")
                    .font(.headline)
                Text("Total expenditure grouped per month")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if filteredMonthlySpends.isEmpty {
                Text("No expense entries in selected time window.")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                Chart(filteredMonthlySpends) { item in
                    BarMark(
                        x: .value("Month", item.month),
                        y: .value("Expense", item.amount)
                    )
                    .foregroundStyle(AppTheme.emeraldGradient)
                    .cornerRadius(6)
                    .annotation(position: .top) {
                        Text(settings.formatCurrency(item.amount))
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.secondary)
                    }
                }
                .frame(height: 220)
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
            }
        }
        .modernCard(padding: 16)
    }
    
    // MARK: - Vehicle Insights Grid
    private var vehicleInsightsGrid: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Performance Highlights")
                .font(.headline)
            
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                if let best = viewModel.bestTripEfficiency {
                    InsightCard(
                        title: "Peak Economy",
                        value: settings.formatEfficiency(best),
                        subtitle: "Best recorded run",
                        icon: "arrow.up.circle.fill",
                        color: .green
                    )
                }
                
                if let worst = viewModel.worstTripEfficiency {
                    InsightCard(
                        title: "Lowest Economy",
                        value: settings.formatEfficiency(worst),
                        subtitle: "Lowest recorded run",
                        icon: "arrow.down.circle.fill",
                        color: .orange
                    )
                }
                
                let avgCost = viewModel.logs.isEmpty ? 0.0 : (viewModel.totalSpent / Double(viewModel.logs.count))
                InsightCard(
                    title: "Avg Fill Cost",
                    value: settings.formatCurrency(avgCost),
                    subtitle: "Per fueling stop",
                    icon: "creditcard.fill",
                    color: .blue
                )
                
                let costPer100 = viewModel.costPerKm * 100
                InsightCard(
                    title: "Cost / 100 \(settings.unitSystem.distanceUnit)",
                    value: costPer100 > 0 ? settings.formatCurrency(costPer100) : "--",
                    subtitle: "Estimated cruise cost",
                    icon: "speedometer",
                    color: .purple
                )
            }
        }
    }
}

// MARK: - Insight Card Component
public struct InsightCard: View {
    public let title: String
    public let value: String
    public let subtitle: String
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
                .font(.system(.title3, design: .rounded, weight: .bold))
                .foregroundColor(.primary)
                .lineLimit(1)
            
            Text(subtitle)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .modernCard(padding: 12)
    }
}
