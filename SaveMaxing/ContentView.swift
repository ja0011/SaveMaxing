import SwiftUI

struct ContentView: View {
    @StateObject private var appModel = AppViewModel()
    @State private var isAdvisorPresented = false
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            DashboardView(appModel: appModel, isAdvisorPresented: $isAdvisorPresented, selectedTab: $selectedTab)
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
                .tag(0)

            GoalsView(appModel: appModel, isAdvisorPresented: $isAdvisorPresented)
                .tabItem {
                    Label("Goals", systemImage: "target")
                }
                .tag(1)

            PurchaseDecisionView(appModel: appModel, selectedTab: $selectedTab)
                .tabItem {
                    Label("Buy It", systemImage: "cart.badge.questionmark")
                }
                .tag(2)

            InsightsView(appModel: appModel)
                .tabItem {
                    Label("Insights", systemImage: "chart.bar.xaxis")
                }
                .tag(3)

            AdminDemoView(appModel: appModel, selectedTab: $selectedTab)
                .tabItem {
                    Label("Admin", systemImage: "slider.horizontal.3")
                }
                .tag(4)
        }
        .tint(Color(red: 0.04, green: 0.28, blue: 0.30))
        .sheet(isPresented: $isAdvisorPresented) {
            SaveMaxingAdvisorSheet(appModel: appModel)
        }
        .task {
            await appModel.load()
        }
    }
}

struct AdminDemoView: View {
    @ObservedObject var appModel: AppViewModel
    @Binding var selectedTab: Int

    @State private var input = ""
    @FocusState private var inputFocused: Bool

    private let brand = Color(red: 0.04, green: 0.28, blue: 0.30)

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Text(appModel.demoDayLabel)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(brand)
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .background(brand.opacity(0.10))

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 10) {
                            ForEach(appModel.demoChatMessages) { message in
                                chatBubble(message)
                                    .id(message.id)
                            }
                            if appModel.isDemoThinking {
                                HStack {
                                    ProgressView()
                                    Text("Simulating…")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                }
                                .padding(.horizontal, 4)
                            }
                        }
                        .padding(16)
                    }
                    .onChange(of: appModel.demoChatMessages.count) {
                        if let last = appModel.demoChatMessages.last {
                            withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                        }
                    }
                }

                Divider()

                VStack(spacing: 8) {
                    quickChips
                    resolveStakeButton
                    HStack(spacing: 10) {
                        TextField("Move the timeline… e.g. next 3 days", text: $input, axis: .vertical)
                            .lineLimit(1...3)
                            .focused($inputFocused)
                            .padding(12)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

                        Button {
                            send()
                        } label: {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.system(size: 32))
                        }
                        .tint(brand)
                        .disabled(appModel.isDemoThinking || input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding(12)
            }
            .navigationTitle("Time Machine")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        appModel.resetDemoChat()
                    } label: {
                        Label("Reset", systemImage: "arrow.counterclockwise")
                    }
                    .tint(brand)
                }
            }
        }
    }

    private var resolveStakeButton: some View {
        VStack(spacing: 6) {
            Button {
                Task { await appModel.resolveDemoStakesNow() }
            } label: {
                Label("Resolve SOL Stake Now", systemImage: "bolt.fill")
                    .font(.caption.weight(.bold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
            }
            .buttonStyle(.borderedProminent)
            .tint(brand)

            if let message = appModel.demoResolveMessage {
                Text(message)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var quickChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(["Next 3 days", "Forward 1 week", "Forward 1 month", "Back 1 week", "Back to start"], id: \.self) { chip in
                    Button {
                        input = chip
                        send()
                    } label: {
                        Text(chip)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(brand.opacity(0.12), in: Capsule())
                            .foregroundStyle(brand)
                    }
                    .disabled(appModel.isDemoThinking)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private func chatBubble(_ message: AdvisorMessage) -> some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }
            Text(message.text)
                .font(.subheadline)
                .padding(12)
                .background(
                    message.role == .user ? brand : Color(.secondarySystemBackground),
                    in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                )
                .foregroundStyle(message.role == .user ? .white : .primary)
            if message.role == .advisor { Spacer(minLength: 40) }
        }
    }

    private func send() {
        let text = input
        input = ""
        inputFocused = false
        appModel.moveDemoFromText(text)
    }
}

#Preview {
    ContentView()
}
