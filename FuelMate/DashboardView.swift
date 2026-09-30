import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = FuelLogViewModel()
    @State private var animateRing = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 30) {
                    // Custom animated progress ring
                    ZStack {
                        Circle()
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 20)
                        
                        Circle()
                            .trim(from: 0, to: animateRing ? 0.75 : 0)
                            .stroke(
                                LinearGradient(gradient: Gradient(colors: [.blue, .purple]), startPoint: .topLeading, endPoint: .bottomTrailing),
                                style: StrokeStyle(lineWidth: 20, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .animation(.easeOut(duration: 1.5).delay(0.2), value: animateRing)
                        
                        VStack {
                            Text("Avg Efficiency")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(String(format: "%.1f", viewModel.averageFuelEfficiency))
                                .font(.system(size: 40, weight: .bold, design: .rounded))
                            Text("miles/gal")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .frame(width: 200, height: 200)
                    .padding(.top, 40)
                    
                    VStack(spacing: 15) {
                        MetricCard(title: "Total Spent", value: String(format: "$%.2f", viewModel.totalFuelSpent), icon: "dollarsign.circle.fill", color: .green)
                        MetricCard(title: "Total Logs", value: "\(viewModel.logs.count)", icon: "list.clipboard.fill", color: .orange)
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                }
            }
            .navigationTitle("Dashboard")
            .onAppear {
                animateRing = true
                viewModel.fetchLogs()
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    NavigationLink(destination: HistoryView(viewModel: viewModel)) {
                        Image(systemName: "clock.fill")
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    NavigationLink(destination: AddLogView(viewModel: viewModel)) {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
        }
    }
}

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(color)
                .frame(width: 40)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.title2)
                    .bold()
            }
            Spacer()
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(15)
    }
}
