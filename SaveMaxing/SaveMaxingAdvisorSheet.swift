import SwiftUI

struct SaveMaxingAdvisorSheet: View {
    @ObservedObject var appModel: AppViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var question = ""
    @State private var isThinking = false

    private let suggestions = [
        "Can I afford something?",
        "Why am I behind on my goal?",
        "Where am I overspending?",
        "How can I save $100 this month?",
        "Find subscriptions I could cut.",
        "What's hurting my goal the most?"
    ]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 16) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("SaveMaxing Advisor")
                                .font(.title2.weight(.black))
                            Text("Ask about purchases, goals, subscriptions, spending behavior, or what is hurting your progress.")
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 8)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(suggestions, id: \.self) { suggestion in
                                Button {
                                    question = suggestion
                                    Task { await sendQuestion() }
                                } label: {
                                    Text(suggestion)
                                        .font(.caption.weight(.bold))
                                        .multilineTextAlignment(.leading)
                                        .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                                        .padding(.horizontal, 10)
                                }
                                .buttonStyle(.bordered)
                                .tint(SaveMaxingTheme.brand)
                            }
                        }

                        ForEach(appModel.advisorMessages) { message in
                            AdvisorBubble(message: message)
                        }

                        if isThinking {
                            HStack(spacing: 10) {
                                ProgressView()
                                Text("Reviewing your financial context")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(14)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        }
                    }
                    .padding(20)
                }

                HStack(spacing: 10) {
                    TextField("Ask SaveMaxing", text: $question, axis: .vertical)
                        .lineLimit(1...4)
                        .padding(12)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                    Button {
                        Task { await sendQuestion() }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32, weight: .bold))
                    }
                    .disabled(question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isThinking)
                }
                .padding(16)
                .background(.regularMaterial)
            }
            .navigationTitle("Advisor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func sendQuestion() async {
        guard !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        let text = question
        question = ""
        isThinking = true
        try? await Task.sleep(for: .milliseconds(350))
        await appModel.askAdvisor(text)
        isThinking = false
    }
}

private struct AdvisorBubble: View {
    let message: AdvisorMessage

    private var isUser: Bool {
        message.role == .user
    }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 40) }

            Text(message.text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(isUser ? .white : .primary)
                .padding(14)
                .background(isUser ? SaveMaxingTheme.brand : SaveMaxingTheme.surface, in: RoundedRectangle(cornerRadius: 8, style: .continuous))

            if !isUser { Spacer(minLength: 40) }
        }
    }
}

#Preview {
    SaveMaxingAdvisorSheet(appModel: AppViewModel())
}
