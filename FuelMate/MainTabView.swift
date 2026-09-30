import SwiftUI

public struct MainTabView: View {
    @StateObject private var viewModel: FuelLogViewModel
    @State private var selectedTab: Int = 0
    
    public init(viewModel: FuelLogViewModel? = nil) {
        if let vm = viewModel {
            _viewModel = StateObject(wrappedValue: vm)
        } else {
            _viewModel = StateObject(wrappedValue: FuelLogViewModel())
        }
    }
    
    public var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(viewModel: viewModel, selectedTab: $selectedTab)
                .tabItem {
                    Label("Dashboard", systemImage: "gauge.with.dots.needle.bottom.50percent")
                }
                .tag(0)
            
            HistoryView(viewModel: viewModel)
                .tabItem {
                    Label("Logs", systemImage: "list.bullet.rectangle.fill")
                }
                .tag(1)
            
            AnalyticsView(viewModel: viewModel)
                .tabItem {
                    Label("Analytics", systemImage: "chart.xyaxis.line")
                }
                .tag(2)
            
            SettingsView(viewModel: viewModel)
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(3)
        }
        .tint(Color(red: 0.0, green: 0.72, blue: 0.83))
    }
}
