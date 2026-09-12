import SwiftUI

struct GoalsView: View {
    @ObservedObject var appModel: AppViewModel
    @Binding var isAdvisorPresented: Bool

    @State private var stakeAmountText = "0.5"
    @State private var walletAddress = ""
    @State private var transactionSignature = ""
    @State private var verificationMessage: String?
    @State private var isVerifying = false

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
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isAdvisorPresented = true
                    } label: {
                        Label("Advisor", systemImage: "sparkles")
                    }
                    .accessibilityLabel("Open SaveMaxing Advisor")
                }
            }
        }
    }

    private var goalsSection: some View {
        VStack(spacing: 12) {
            ForEach(appModel.goals) { goal in
                goalCard(goal)
            }
        }
    }

    private func goalCard(_ goal: SavingsGoal) -> some View {
        Button {
            appModel.activeGoalID = goal.id
            verificationMessage = nil
        } label: {
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
                    Label("Optional SOL stake available", systemImage: "lock.open.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                goal.id == appModel.activeGoalID ? .green.opacity(0.14) : Color(.secondarySystemBackground),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(goal.id == appModel.activeGoalID ? Color.green.opacity(0.45) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var stakeFlowCard: some View {
        let goal = appModel.activeGoal

        return VStack(alignment: .leading, spacing: 16) {
            SectionTitle(title: "Optional SOL Stake", systemImage: "lock.shield.fill")

            Text("Attach a real Solana devnet transfer to \(goal.name). SaveMaxing will not mark the stake funded until a devnet transaction signature is confirmed.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Label("Devnet Demo - No Real Money", systemImage: "testtube.2")
                .font(.subheadline.weight(.black))
                .foregroundStyle(.blue)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

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

            Button {
                appModel.prepareStake(for: goal.id, committedSol: Decimal(string: stakeAmountText) ?? 0.5)
                verificationMessage = "Stake selected. Send devnet SOL from your wallet, then paste the real transaction signature."
            } label: {
                Label("Select Stake for \(goal.name)", systemImage: "plus.circle.fill")
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(.green)

            if let stake = appModel.activeGoal.stake {
                Divider()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Demo escrow wallet")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text(stake.escrowWalletAddress)
                        .font(.caption.monospaced())
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                        .lineLimit(2)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                    Text("Open Phantom or another Solana wallet, switch to devnet, send exactly \(stake.committedSol.formattedSOL) to the demo escrow wallet, then paste the real transaction signature below.")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Button {
                        openWallet()
                        appModel.markStakeAwaitingApproval(for: goal.id, walletAddress: walletAddress)
                    } label: {
                        Label("Open Wallet", systemImage: "wallet.pass.fill")
                            .fontWeight(.bold)
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                    }
                    .buttonStyle(.bordered)

                    TextField("Wallet address", text: $walletAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.subheadline.monospaced())
                        .textSelection(.enabled)
                        .padding(14)
                        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                    TextField("Devnet transaction signature", text: $transactionSignature)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .font(.subheadline.monospaced())
                        .textSelection(.enabled)
                        .padding(14)
                        .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                    Button {
                        Task { await verifySignature(goalID: goal.id) }
                    } label: {
                        HStack {
                            if isVerifying {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "checkmark.seal.fill")
                            }
                            Text(isVerifying ? "Checking Devnet" : "Verify Devnet Transaction")
                                .fontWeight(.bold)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .disabled(isVerifying || transactionSignature.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if let verificationMessage {
                        Text(verificationMessage)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(appModel.activeGoal.stake?.state == .stakeConfirmed ? .green : .orange)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(18)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var appBackground: some View {
        LinearGradient(colors: [Color(.systemBackground), Color.green.opacity(0.07)], startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }

    private func verifySignature(goalID: UUID) async {
        isVerifying = true
        let confirmed = await appModel.verifyStakeTransaction(for: goalID, signature: transactionSignature, walletAddress: walletAddress)
        verificationMessage = confirmed ? "Confirmed on Solana Devnet. This signature can be verified in Solana Explorer." : "Not confirmed yet. The stake remains pending until Solana devnet confirms the signature."
        isVerifying = false
    }

    private func openWallet() {
        guard let url = URL(string: "https://phantom.app/ul/browse/https%3A%2F%2Fexplorer.solana.com%2F%3Fcluster%3Ddevnet") else { return }
        UIApplication.shared.open(url)
    }
}

#Preview {
    GoalsView(appModel: AppViewModel(), isAdvisorPresented: .constant(false))
}
