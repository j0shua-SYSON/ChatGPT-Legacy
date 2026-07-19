import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        SettingsContent(model: model, settings: model.settings, dismiss: dismiss)
    }
}

private struct SettingsContent: View {
    @ObservedObject var model: AppModel
    @ObservedObject var settings: AppSettings
    let dismiss: DismissAction
    @State private var instructionsHeight: CGFloat = 132
    @State private var instructionsFocused = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 14) {
                    responseCard
                    instructionsCard
                    modelCard
                    behaviorCard
                    disclosureCard
                }
                .padding(16)
            }
            .background(LegacyTheme.canvas.ignoresSafeArea())
            .navigationTitle("Response settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("settings.done")
                }
            }
        }
        .navigationViewStyle(.stack)
        .accessibilityIdentifier("settings.screen")
    }

    private var responseCard: some View {
        settingCard {
            SectionLabel(text: "Response style")
            Picker("Response style", selection: $settings.responseStyle) {
                ForEach(ResponseStyle.allCases) { style in
                    Text(style.label).tag(style)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityIdentifier("settings.responseStyle")

            Divider().background(LegacyTheme.hairline)

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Reasoning effort")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(LegacyTheme.ink)
                    Text("Higher effort can take longer")
                        .font(.caption)
                        .foregroundColor(LegacyTheme.muted)
                }
                Spacer()
                Picker("Reasoning effort", selection: $settings.reasoning) {
                    ForEach(ReasoningChoice.allCases) { choice in
                        Text(choice.label).tag(choice)
                    }
                }
                .pickerStyle(.menu)
                .accessibilityIdentifier("settings.reasoning")
            }
        }
    }

    private var instructionsCard: some View {
        settingCard {
            SectionLabel(text: "Custom instructions")
            Text("Applied privately to every new response.")
                .font(.caption)
                .foregroundColor(LegacyTheme.muted)
            GrowingTextView(
                text: $settings.customInstructions,
                calculatedHeight: $instructionsHeight,
                isFirstResponder: $instructionsFocused,
                maxHeight: 180
            )
            .frame(height: max(108, instructionsHeight))
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(LegacyTheme.canvas)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .stroke(LegacyTheme.hairline, lineWidth: 1)
            )
            .accessibilityIdentifier("settings.instructions")
        }
    }

    private var modelCard: some View {
        settingCard {
            HStack {
                SectionLabel(text: "Model")
                Spacer()
                if model.isLoadingModels { ProgressView().scaleEffect(0.7) }
            }
            ForEach(model.pickerModels) { item in
                Button {
                    model.selectModel(item)
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: model.currentModel?.id == item.id
                            ? "checkmark.circle.fill"
                            : "circle")
                            .foregroundColor(
                                model.currentModel?.id == item.id
                                    ? LegacyTheme.signal
                                    : LegacyTheme.faint
                            )
                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.displayName)
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(LegacyTheme.ink)
                            if let description = item.description, !description.isEmpty {
                                Text(description)
                                    .font(.caption)
                                    .foregroundColor(LegacyTheme.muted)
                                    .lineLimit(2)
                            }
                        }
                        Spacer()
                    }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings.model.\(item.id)")
            }
            Button(action: model.refreshModels) {
                Label("Refresh model catalog", systemImage: "arrow.triangle.2.circlepath")
                    .font(.subheadline.weight(.semibold))
            }
            .accessibilityIdentifier("settings.refreshModels")
        }
    }

    private var behaviorCard: some View {
        settingCard {
            SectionLabel(text: "Behavior")
            Toggle("Haptic feedback", isOn: $settings.hapticsEnabled)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(LegacyTheme.ink)
                .accessibilityIdentifier("settings.haptics")
        }
    }

    private var disclosureCard: some View {
        settingCard {
            HStack(alignment: .top, spacing: 11) {
                Image(systemName: "info.circle")
                    .foregroundColor(LegacyTheme.signal)
                    .padding(.top, 1)
                Text("ChatGPT Legacy is an unofficial open-source client. It uses the Codex subscription OAuth and Responses paths, which OpenAI may change. Conversations are stored locally; prompts and attachments are sent to OpenAI when you message.")
                    .font(.footnote)
                    .foregroundColor(LegacyTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func settingCard<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 13, content: content)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(LegacyTheme.paper)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(LegacyTheme.hairline, lineWidth: 1)
            )
    }
}
