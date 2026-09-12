import SwiftUI

struct ContentView: View {
    @StateObject private var appModel = AppViewModel()
    @State private var isAdvisorPresented = false

    var body: some View {
        TabView {
            DashboardView(appModel: appModel, isAdvisorPresented: $isAdvisorPresented)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }

            GoalsView(appModel: appModel, isAdvisorPresented: $isAdvisorPresented)
                .tabItem {
                    Label("Goals", systemImage: "target")
                }

            PurchaseDecisionView(appModel: appModel)
                .tabItem {
                    Label("Buy It", systemImage: "cart.badge.questionmark")
                }

            InsightsView(appModel: appModel)
                .tabItem {
                    Label("Insights", systemImage: "chart.bar.xaxis")
                }
        }
        .tint(.green)
        .sheet(isPresented: $isAdvisorPresented) {
            SaveMaxingAdvisorSheet(appModel: appModel)
        }
        .task {
            await appModel.load()
        }
    }
}

#Preview {
    ContentView()
}
