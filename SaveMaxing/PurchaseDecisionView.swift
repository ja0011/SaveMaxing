import SwiftUI

struct PurchaseDecisionView: View {
    @ObservedObject var appModel: AppViewModel
    @Binding var selectedTab: Int

    @State private var itemName = "Xbox"
    @State private var priceText = "600"
    @State private var decision: PurchaseDecision?
    @State private var isAnalyzing = false
    @State private var protectedAmount: Decimal?
    @State private var showCelebration = false
    @FocusState private var focusedField: Field?

    private enum Field {
        case item
        case price
    }

    private var purchasePrice: Decimal? {
        Decimal(string: priceText.filter { $0.isNumber || $0 == "." })
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    if appModel.goals.isEmpty {
                        noGoalCard
                    } else {
                        headerCard
                        inputCard

                        if isAnalyzing {
                            analyzingCard
                        }

                        if let decision {
                            decisionCard(decision)
                        }

                        if let protectedAmount {
                            protectedCard(amount: protectedAmount)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 28)
            }
            .background(appBackground)
            .navigationTitle("Should I Buy It?")
        }
    }

    /// Shown when there's no active goal — nothing to weigh a purchase against.
    private var noGoalCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "cart.badge.questionmark")
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(SaveMaxingTheme.brand)
                .frame(width: 68, height: 68)
                .background(SaveMaxingTheme.accentSoft, in: Circle())

            Text("No goal in mind")
                .font(.title3.weight(.bold))

            Text("You're not saving for anything right now, so there's nothing to check this purchase against. Create a goal first.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                selectedTab = 1   // Goals tab
            } label: {
                Label("Create a Goal", systemImage: "target")
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
            }
            .buttonStyle(.borderedProminent)
            .tint(SaveMaxingTheme.brand)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: "sparkles")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .background(SaveMaxingTheme.brand, in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text("Before you spend")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                    Text("Check the goal impact in seconds.")
                        .font(.headline.weight(.bold))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 10) {
                MetricPillSmall(title: "Remaining", value: appModel.activeGoal.amountRemaining.formattedCurrency)
                MetricPillSmall(title: "Progress", value: "\(appModel.activeGoal.progressPercentage)%")
                MetricPillSmall(title: "Days", value: "\(appModel.activeGoal.daysRemaining)")
            }
        }
        .padding(18)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var inputCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Purchase")
                .font(.headline.weight(.bold))

            VStack(spacing: 12) {
                TextField("Item", text: $itemName)
                    .textInputAutocapitalization(.words)
                    .focused($focusedField, equals: .item)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .price }
                    .padding(14)
                    .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                HStack(spacing: 10) {
                    Text("$")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.secondary)
                    TextField("Price", text: $priceText)
                        .keyboardType(.decimalPad)
                        .focused($focusedField, equals: .price)
                }
                .padding(14)
                .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            Button {
                Task { await analyzePurchase() }
            } label: {
                HStack {
                    if isAnalyzing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "wand.and.stars")
                    }
                    Text(isAnalyzing ? "Analyzing" : "Analyze Purchase")
                        .fontWeight(.bold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
            }
            .buttonStyle(.borderedProminent)
            .tint(SaveMaxingTheme.brand)
            .disabled(isAnalyzing || itemName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || purchasePrice == nil)
        }
        .padding(18)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var analyzingCard: some View {
        HStack(spacing: 12) {
            ProgressView()
            VStack(alignment: .leading, spacing: 4) {
                Text("Gemini analysis")
                    .font(.subheadline.weight(.bold))
                Text("Checking this purchase against your active goal and real spending history.")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
        .background(SaveMaxingTheme.info.opacity(0.10), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func decisionCard(_ decision: PurchaseDecision) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(SaveMaxingTheme.warning)

                VStack(alignment: .leading, spacing: 4) {
                    Text(decision.recommendation.rawValue.uppercased())
                        .font(.title3.weight(.black))
                    Text(decision.summary)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 10) {
                ForEach(decision.reasons, id: \.self) { reason in
                    Label(reason, systemImage: "checkmark.circle.fill")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Alternatives")
                    .font(.headline.weight(.bold))
                ForEach(decision.alternatives, id: \.self) { alternative in
                    Text("• \(alternative)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 12) {
                Button {
                    protectedAmount = nil
                } label: {
                    Text("Buy Anyway")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                }
                .buttonStyle(.bordered)
                .tint(.secondary)

                Button {
                    skipAndSave(decision.price)
                } label: {
                    Text("Skip & Save")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                }
                .buttonStyle(.borderedProminent)
                .tint(SaveMaxingTheme.brand)
            }
        }
        .padding(18)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func protectedCard(amount: Decimal) -> some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(SaveMaxingTheme.accentSoft)
                    .frame(width: 82, height: 82)
                    .scaleEffect(showCelebration ? 1.12 : 0.86)
                Image(systemName: "target")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(SaveMaxingTheme.brand)
                    .scaleEffect(showCelebration ? 1.0 : 0.76)
            }
            .animation(.spring(response: 0.5, dampingFraction: 0.58), value: showCelebration)

            Text("\(amount.formattedCurrency) protected toward your goal")
                .font(.title3.weight(.bold))
                .multilineTextAlignment(.center)
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(SaveMaxingTheme.cardGradient(tint: SaveMaxingTheme.accent), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var appBackground: some View {
        SaveMaxingTheme.background
            .ignoresSafeArea()
    }

    private func analyzePurchase() async {
        guard let purchasePrice else { return }
        focusedField = nil
        protectedAmount = nil
        decision = nil
        isAnalyzing = true

        do {
            decision = try await appModel.analyzePurchase(itemName: itemName, price: purchasePrice)
        } catch {
            decision = PurchaseDecision(
                id: UUID(),
                itemName: itemName,
                price: purchasePrice,
                recommendation: .caution,
                summary: "This purchase needs a second look before it fits your savings plan.",
                reasons: ["Live analysis is unavailable, so the app used your local savings context."],
                alternatives: ["Wait 7 days", "Compare prices", "Offset it by cancelling a subscription"]
            )
        }

        isAnalyzing = false
    }

    private func skipAndSave(_ amount: Decimal) {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
            appModel.protectPurchase(price: amount)
            protectedAmount = amount
            showCelebration = false
        }

        withAnimation(.spring(response: 0.55, dampingFraction: 0.52).delay(0.05)) {
            showCelebration = true
        }
    }
}

private struct MetricPillSmall: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline.weight(.bold))
                .minimumScaleFactor(0.72)
                .lineLimit(1)
            Text(title)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 58)
        .background(Color(.systemBackground).opacity(0.74), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

#Preview {
    PurchaseDecisionView(appModel: AppViewModel(), selectedTab: .constant(2))
}
