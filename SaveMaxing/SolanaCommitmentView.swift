import SwiftUI

struct SolanaCommitmentView: View {
    @ObservedObject var appModel: AppViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(.green)
                    .frame(width: 86, height: 86)
                    .background(.green.opacity(0.12), in: Circle())

                Text("SOL stakes live inside Goals")
                    .font(.title2.weight(.black))
                    .multilineTextAlignment(.center)

                Text("Select a goal, choose an optional devnet stake, submit a real wallet transaction, then verify the signature before SaveMaxing marks it funded.")
                    .font(.body.weight(.medium))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                if let stake = appModel.activeGoal.stake {
                    StakeStatusBanner(stake: stake)
                }
            }
            .padding(28)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                LinearGradient(colors: [Color(.systemBackground), Color.green.opacity(0.08)], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            )
            .navigationTitle("Stake")
        }
    }
}

#Preview {
    SolanaCommitmentView(appModel: AppViewModel())
}
