import SwiftUI
import UIKit

struct GoalsView: View {
    @ObservedObject var appModel: AppViewModel
    @Binding var isAdvisorPresented: Bool

    @State private var stakeAmountText = "0.5"
    @State private var successWallet = ""
    @State private var selectedCharityId = "red-cross"
    @State private var verificationMessage: String?

    @State private var goalPrompt = ""
    @State private var isGeneratingGoal = false
    @State private var goalError: String?
    @State private var showWalletManager = false

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    goalsSection
                    stakeFlowCard
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background(appBackground)
            .navigationTitle("Goals")
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isAdvisorPresented = true
                    } label: {
                        Label("Advisor", systemImage: "sparkles")
                    }
                    .accessibilityLabel("Open SaveMaxing Advisor")
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { hideKeyboard() }
                        .fontWeight(.bold)
                }
            }
            .sheet(isPresented: $showWalletManager) {
                WalletManagerView(appModel: appModel, selectedAddress: $successWallet)
            }
        }
    }

    private var goalsSection: some View {
        VStack(spacing: 12) {
            goalAdvisorCard

            ForEach(appModel.goals) { goal in
                goalCard(goal)
            }
        }
    }

    /// Describe a goal in plain English; Gemini generates a real goal card.
    private var goalAdvisorCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle(title: "Goal Advisor", systemImage: "sparkles")

            Text("Describe a goal and AI will create it for you.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)

            TextField("e.g. Don't spend $100 this week", text: $goalPrompt, axis: .vertical)
                .lineLimit(1...3)
                .padding(14)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            Button {
                Task { await generateGoal() }
            } label: {
                HStack {
                    if isGeneratingGoal {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "wand.and.stars")
                    }
                    Text(isGeneratingGoal ? "Creating goal" : "Generate Goal")
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(SaveMaxingTheme.brand)
            .disabled(isGeneratingGoal || goalPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if let goalError {
                Text(goalError)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(SaveMaxingTheme.warning)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .background(
            SaveMaxingTheme.cardGradient(tint: SaveMaxingTheme.accent),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
    }

    private func generateGoal() async {
        let prompt = goalPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !prompt.isEmpty else { return }
        isGeneratingGoal = true
        goalError = nil
        do {
            try await appModel.createGoal(fromPrompt: prompt)
            goalPrompt = ""
        } catch {
            goalError = "Couldn't reach the AI advisor. Make sure the backend is running and on the same Wi-Fi."
        }
        isGeneratingGoal = false
    }

    private func goalCard(_ goal: SavingsGoal) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(goal.kind.rawValue)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text(goal.name)
                        .font(.title3.weight(.black))
                        .foregroundStyle(.primary)
                }

                Spacer()

                Label(goal.health.rawValue, systemImage: goal.health.symbolName)
                    .font(.caption.weight(.black))
                    .foregroundStyle(goal.health.tint)

                // Demo-only: remove a goal card.
                Button(role: .destructive) {
                    appModel.deleteGoal(goal.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(SaveMaxingTheme.danger)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete goal")
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("\(goal.currentAmount.formattedCurrency) / \(goal.targetAmount.formattedCurrency)")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.primary)
                    Spacer()
                    Text("\(goal.daysRemaining) days")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }

                ProgressView(value: goal.progress)
                    .tint(goal.health.tint)
            }

            if let stake = goal.stake {
                StakeStatusBanner(stake: stake)

                if stake.state == .stakeConfirmed, let url = stake.explorerURL {
                    Link(destination: url) {
                        Label("View Transaction", systemImage: "arrow.up.right.square.fill")
                            .font(.subheadline.weight(.bold))
                    }
                }
            } else {
                Label("SOL stake not created yet", systemImage: "lock.open.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            if goal.isFailed {
                failedBanner(goal)
            } else if goal.isAchieved {
                achievedBanner(goal)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            goal.id == appModel.activeGoalID ? SaveMaxingTheme.brandLight : SaveMaxingTheme.surface,
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(goal.id == appModel.activeGoalID ? SaveMaxingTheme.brand.opacity(0.36) : Color.clear, lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .onTapGesture {
            appModel.activeGoalID = goal.id
            verificationMessage = nil
        }
    }

    /// Shown when the timeline pushes a goal past its limit / deadline.
    private func failedBanner(_ goal: SavingsGoal) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Goal Failed", systemImage: "xmark.octagon.fill")
                .font(.headline.weight(.bold))
                .foregroundStyle(SaveMaxingTheme.danger)

            if let stake = goal.stake {
                let charityName = appModel.charities.first(where: { $0.id == stake.charityId })?.name ?? "charity"
                Text("\(stake.committedSol.formattedSOL) lost — forfeited to \(charityName).")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("No SOL was staked on this goal.")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Button(role: .destructive) {
                appModel.deleteGoal(goal.id)
            } label: {
                Label("Delete Goal", systemImage: "trash")
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(.borderedProminent)
            .tint(SaveMaxingTheme.danger)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SaveMaxingTheme.danger.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    /// Shown when the goal is met.
    private func achievedBanner(_ goal: SavingsGoal) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Goal Achieved", systemImage: "checkmark.seal.fill")
                .font(.headline.weight(.bold))
                .foregroundStyle(SaveMaxingTheme.success)

            if let stake = goal.stake {
                Text("\(stake.committedSol.formattedSOL) returned to \(stake.successWallet.shortAddress).")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("Nice work staying on track.")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Button(role: .destructive) {
                appModel.deleteGoal(goal.id)
            } label: {
                Label("Delete Goal", systemImage: "trash")
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
            }
            .buttonStyle(.bordered)
            .tint(SaveMaxingTheme.success)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(SaveMaxingTheme.success.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var stakeFlowCard: some View {
        let goal = appModel.activeGoal

        return VStack(alignment: .leading, spacing: 16) {
            SectionTitle(title: "SOL Stake", systemImage: "lock.shield.fill")

            Text("Set the stake amount, your payout wallet, and where the SOL goes if the goal misses.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Label("Devnet Demo - No Real Money", systemImage: "testtube.2")
                .font(.subheadline.weight(.black))
                .foregroundStyle(SaveMaxingTheme.info)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(SaveMaxingTheme.info.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 8) {
                Text("Stake amount")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                HStack {
                    TextField("0.5", text: $stakeAmountText)
                        .keyboardType(.decimalPad)
                    Text("SOL")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                .padding(14)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Your wallet address")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        showWalletManager = true
                    } label: {
                        Label("Add / Manage", systemImage: "wallet.pass")
                            .font(.caption.weight(.bold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(SaveMaxingTheme.brand)
                }

                Picker("Wallet", selection: $successWallet) {
                    ForEach(appModel.savedWallets) { wallet in
                        Text(wallet.shortLabel).tag(wallet.address)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .onAppear {
                    if !appModel.savedWallets.contains(where: { $0.address == successWallet }) {
                        successWallet = appModel.savedWallets.first?.address ?? ""
                    }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("If goal fails, send stake to")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                Picker("Charity", selection: $selectedCharityId) {
                    ForEach(appModel.charities) { charity in
                        Text(charity.name).tag(charity.id)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            Button {
                appModel.prepareStake(
                    for: goal.id,
                    committedSol: Decimal(string: stakeAmountText) ?? 0.5,
                    successWallet: successWallet,
                    charityId: selectedCharityId
                )
                verificationMessage = "Stake created for \(goal.name)."
            } label: {
                Label("Create Stake for \(goal.name)", systemImage: "plus.circle.fill")
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(SaveMaxingTheme.brand)

            if let stake = appModel.activeGoal.stake {
                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Label("\(stake.committedSol.formattedSOL) stake active", systemImage: "lock.shield.fill")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(SaveMaxingTheme.brand)

                    if let charity = appModel.charities.first(where: { $0.id == stake.charityId }) {
                        Label("Success pays \(stake.successWallet.shortAddress). Missed goal pays \(charity.name).", systemImage: "arrow.triangle.branch")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Label("Demo payout runs automatically when the final month resolves.", systemImage: "bolt.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if let outcome = stake.resolutionOutcome {
                        Label("Resolved as \(outcome.rawValue).", systemImage: "checkmark.seal.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(SaveMaxingTheme.success)
                    }

                    if let verificationMessage {
                        Text(verificationMessage)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if let payoutURL = stake.payoutExplorerURL {
                        Link(destination: payoutURL) {
                            Label("View on Solana Explorer", systemImage: "arrow.up.right.square.fill")
                                .font(.subheadline.weight(.bold))
                        }
                    }
                }
            }
        }
        .padding(18)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var appBackground: some View {
        SaveMaxingTheme.background
            .ignoresSafeArea()
    }

    /// Dismisses the keyboard from any focused text field.
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

}

/// Lets the user pick, add, or remove payout wallets — a dropdown-friendly
/// alternative to pasting an address into a text box.
struct WalletManagerView: View {
    @ObservedObject var appModel: AppViewModel
    @Binding var selectedAddress: String
    @Environment(\.dismiss) private var dismiss

    @State private var newLabel = ""
    @State private var newAddress = ""

    var body: some View {
        NavigationStack {
            List {
                Section("Your wallets") {
                    ForEach(appModel.savedWallets) { wallet in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(wallet.label)
                                    .font(.subheadline.weight(.semibold))
                                Text(wallet.address)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer()
                            if wallet.address == selectedAddress {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { selectedAddress = wallet.address }
                    }
                    .onDelete { indexSet in
                        for index in indexSet {
                            let wallet = appModel.savedWallets[index]
                            appModel.removeWallet(wallet.id)
                            if selectedAddress == wallet.address {
                                selectedAddress = appModel.savedWallets.first?.address ?? ""
                            }
                        }
                    }
                }

                Section("Add a wallet") {
                    TextField("Label (optional)", text: $newLabel)
                    TextField("Wallet address", text: $newAddress)
                        .font(.subheadline.monospaced())
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    Button {
                        appModel.addWallet(label: newLabel, address: newAddress)
                        if let added = appModel.savedWallets.last { selectedAddress = added.address }
                        newLabel = ""
                        newAddress = ""
                    } label: {
                        Label("Add Wallet", systemImage: "plus.circle.fill")
                    }
                    .disabled(newAddress.trimmingCharacters(in: .whitespaces).isEmpty)

                    Button {
                        let wallet = appModel.addDemoWallet()
                        selectedAddress = wallet.address
                    } label: {
                        Label("Add Demo Wallet", systemImage: "wand.and.stars")
                    }
                }
            }
            .navigationTitle("Wallets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
            }
        }
    }
}

#Preview {
    GoalsView(appModel: AppViewModel(), isAdvisorPresented: .constant(false))
}
