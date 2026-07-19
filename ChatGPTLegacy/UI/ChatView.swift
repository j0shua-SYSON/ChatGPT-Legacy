import SwiftUI
import UIKit

struct ChatView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var speech = SpeechTranscriber()
    @State private var activeSheet: ActiveSheet?
    @State private var composerHeight: CGFloat = 48
    @State private var composerFocused = false
    @State private var dictationPrefix = ""

    var body: some View {
        VStack(spacing: 0) {
            header
            Rectangle()
                .fill(LegacyTheme.hairline)
                .frame(height: 1)
            messageArea
            composer
        }
        .background(LegacyTheme.canvas.ignoresSafeArea())
        .accessibilityIdentifier("chat.screen")
        .sheet(item: $activeSheet) { sheet in
            sheetView(sheet)
        }
        .onChange(of: speech.transcript) { transcript in
            guard speech.isRecording || !transcript.isEmpty else { return }
            let separator = dictationPrefix.isEmpty || dictationPrefix.hasSuffix(" ") ? "" : " "
            model.draft = dictationPrefix + separator + transcript
        }
        .onChange(of: speech.errorMessage) { message in
            if let message {
                model.errorMessage = message
                speech.errorMessage = nil
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Button {
                activeSheet = .history
            } label: {
                Image(systemName: "line.3.horizontal")
            }
            .buttonStyle(IconButtonStyle())
            .accessibilityLabel("Conversation history")
            .accessibilityIdentifier("chat.history")

            VStack(alignment: .leading, spacing: 2) {
                Text(model.activeConversation?.title ?? "ChatGPT Legacy")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundColor(LegacyTheme.ink)
                    .lineLimit(1)

                Menu {
                    if model.pickerModels.isEmpty {
                        Button("Refresh models", action: model.refreshModels)
                    } else {
                        ForEach(model.pickerModels) { item in
                            Button {
                                model.selectModel(item)
                            } label: {
                                if model.currentModel?.id == item.id {
                                    Label(item.displayName, systemImage: "checkmark")
                                } else {
                                    Text(item.displayName)
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        if model.isLoadingModels {
                            ProgressView().scaleEffect(0.55)
                        }
                        Text(model.currentModel?.displayName ?? "No model")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(LegacyTheme.signal)
                            .lineLimit(1)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundColor(LegacyTheme.signal)
                    }
                }
                .accessibilityLabel("Select model")
                .accessibilityIdentifier("chat.modelPicker")
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Menu {
                Button {
                    activeSheet = .prompts
                } label: {
                    Label("Prompt library", systemImage: "sparkles")
                }
                Button {
                    activeSheet = .settings
                } label: {
                    Label("Response settings", systemImage: "slider.horizontal.3")
                }
                Button {
                    if let export = model.activeConversation?.markdownExport {
                        activeSheet = .share(export)
                    }
                } label: {
                    Label("Export conversation", systemImage: "square.and.arrow.up")
                }
                .disabled(model.activeMessages.isEmpty)
                Button(action: model.regenerateLastResponse) {
                    Label("Regenerate last response", systemImage: "arrow.clockwise")
                }
                .disabled(
                    model.isGenerating || model.activeMessages.last?.role != .assistant
                )
                Divider()
                Button(action: model.refreshModels) {
                    Label("Refresh models", systemImage: "arrow.triangle.2.circlepath")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(LegacyTheme.ink)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(LegacyTheme.paper))
                    .overlay(Circle().stroke(LegacyTheme.hairline, lineWidth: 1))
            }
            .accessibilityLabel("Conversation actions")
            .accessibilityIdentifier("chat.actions")

            Button(action: model.createConversation) {
                Image(systemName: "square.and.pencil")
            }
            .buttonStyle(IconButtonStyle())
            .accessibilityLabel("New conversation")
            .accessibilityIdentifier("chat.new")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(LegacyTheme.canvas)
    }

    private var messageArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 3) {
                    if model.activeMessages.isEmpty {
                        EmptyConversationView { preset in
                            model.applyPrompt(preset)
                            composerFocused = true
                        }
                        .frame(minHeight: 410)
                    } else {
                        ForEach(Array(model.activeMessages.enumerated()), id: \.element.id) {
                            index, message in
                            MessageRow(
                                message: message,
                                isLast: index == model.activeMessages.count - 1,
                                isGenerating: model.isGenerating,
                                onEdit: {
                                    model.beginEditing(message)
                                    composerFocused = true
                                },
                                onRegenerate: model.regenerateLastResponse,
                                onShare: { activeSheet = .share($0) }
                            )
                        }
                    }
                    Color.clear
                        .frame(height: 1)
                        .id("conversation-bottom")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .onChange(of: model.scrollSignal) { _ in
                if reduceMotion {
                    proxy.scrollTo("conversation-bottom", anchor: .bottom)
                } else {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo("conversation-bottom", anchor: .bottom)
                    }
                }
            }
        }
    }

    private var composer: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(LegacyTheme.hairline)
                .frame(height: 1)

            if model.editingMessageID != nil {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.branch")
                        .foregroundColor(LegacyTheme.signal)
                    Text("Editing an earlier message will branch this conversation")
                        .font(.caption)
                        .foregroundColor(LegacyTheme.muted)
                        .lineLimit(2)
                    Spacer()
                    Button(action: model.cancelEditing) {
                        Image(systemName: "xmark")
                            .font(.caption.bold())
                            .frame(width: 30, height: 30)
                    }
                    .accessibilityLabel("Cancel editing")
                }
                .padding(.horizontal, 16)
                .padding(.top, 9)
                .accessibilityIdentifier("composer.editing")
            }

            if !model.pendingAttachments.isEmpty {
                pendingAttachmentStrip
            }

            HStack(alignment: .bottom, spacing: 9) {
                Menu {
                    Button {
                        activeSheet = .imagePicker(.photoLibrary)
                    } label: {
                        Label("Photo library", systemImage: "photo")
                    }
                    Button {
                        activeSheet = .imagePicker(.camera)
                    } label: {
                        Label("Camera", systemImage: "camera")
                    }
                    .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
                    Button {
                        activeSheet = .prompts
                    } label: {
                        Label("Prompt library", systemImage: "sparkles")
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(LegacyTheme.ink)
                        .frame(width: 42, height: 42)
                        .background(Circle().fill(LegacyTheme.canvas))
                }
                .accessibilityLabel("Add to message")
                .accessibilityIdentifier("composer.add")

                ZStack(alignment: .topLeading) {
                    if model.draft.isEmpty {
                        Text("Message ChatGPT")
                            .font(.body)
                            .foregroundColor(LegacyTheme.faint)
                            .padding(.leading, 5)
                            .padding(.top, 10)
                            .allowsHitTesting(false)
                    }
                    GrowingTextView(
                        text: $model.draft,
                        calculatedHeight: $composerHeight,
                        isFirstResponder: $composerFocused
                    )
                    .frame(height: composerHeight)
                }
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(LegacyTheme.canvas)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            composerFocused ? LegacyTheme.signal.opacity(0.65) : LegacyTheme.hairline,
                            lineWidth: 1
                        )
                )

                Button {
                    dictationPrefix = model.draft
                    speech.toggle()
                } label: {
                    Image(systemName: speech.isRecording ? "waveform" : "mic")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(
                            speech.isRecording ? LegacyTheme.userText : LegacyTheme.ink
                        )
                        .frame(width: 42, height: 42)
                        .background(
                            Circle().fill(
                                speech.isRecording ? LegacyTheme.signal : LegacyTheme.canvas
                            )
                        )
                }
                .accessibilityLabel(speech.isRecording ? "Stop dictation" : "Start dictation")
                .accessibilityIdentifier("composer.mic")

                Button {
                    if model.isGenerating {
                        model.stopGenerating()
                    } else {
                        composerFocused = false
                        speech.stop()
                        model.sendDraft()
                    }
                } label: {
                    Image(systemName: model.isGenerating ? "stop.fill" : "arrow.up")
                }
                .buttonStyle(IconButtonStyle(emphasized: true))
                .disabled(!canSend && !model.isGenerating)
                .opacity(!canSend && !model.isGenerating ? 0.42 : 1)
                .accessibilityLabel(model.isGenerating ? "Stop response" : "Send message")
                .accessibilityIdentifier(
                    model.isGenerating ? "composer.stop" : "composer.send"
                )
            }
            .padding(.horizontal, 12)
            .padding(.top, 9)
            .padding(.bottom, 10)
        }
        .background(LegacyTheme.paper)
    }

    private var pendingAttachmentStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(model.pendingAttachments) { attachment in
                    ZStack(alignment: .topTrailing) {
                        if let image = UIImage(data: attachment.data) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 68, height: 54)
                                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                        Button {
                            model.removePendingAttachment(attachment.id)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 22, height: 22)
                                .background(Circle().fill(Color.black.opacity(0.72)))
                        }
                        .offset(x: 5, y: -5)
                        .accessibilityLabel("Remove attached image")
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 10)
        }
        .accessibilityIdentifier("composer.attachments")
    }

    private var canSend: Bool {
        (!model.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !model.pendingAttachments.isEmpty) && model.currentModel != nil
    }

    @ViewBuilder
    private func sheetView(_ sheet: ActiveSheet) -> some View {
        switch sheet {
        case .history:
            HistoryView()
                .environmentObject(model)
        case .settings:
            SettingsView()
                .environmentObject(model)
        case .prompts:
            PromptLibraryView { preset in
                model.applyPrompt(preset)
                activeSheet = nil
                composerFocused = true
            }
        case .imagePicker(let source):
            ImagePicker(
                sourceType: source,
                onImage: { image in
                    model.attach(image: image)
                    activeSheet = nil
                },
                onCancel: { activeSheet = nil }
            )
            .ignoresSafeArea()
        case .share(let text):
            ShareSheet(items: [text])
                .ignoresSafeArea()
        }
    }
}

private enum ActiveSheet: Identifiable {
    case history
    case settings
    case prompts
    case imagePicker(UIImagePickerController.SourceType)
    case share(String)

    var id: String {
        switch self {
        case .history: return "history"
        case .settings: return "settings"
        case .prompts: return "prompts"
        case .imagePicker(let source): return "picker-\(source.rawValue)"
        case .share: return "share"
        }
    }
}

private struct EmptyConversationView: View {
    let onPreset: (PromptPreset) -> Void

    private let featured = Array(PromptPreset.builtIn.prefix(3))

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Spacer(minLength: 22)
            LegacyMark()
            VStack(alignment: .leading, spacing: 8) {
                Text("What are we\nthinking through?")
                    .font(LegacyTheme.display)
                    .foregroundColor(LegacyTheme.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Start plainly, attach what you see, or borrow a useful shape.")
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundColor(LegacyTheme.muted)
                    .lineSpacing(3)
            }

            VStack(spacing: 8) {
                ForEach(featured) { preset in
                    Button {
                        onPreset(preset)
                    } label: {
                        HStack(spacing: 12) {
                            Text(preset.title)
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(LegacyTheme.ink)
                            Spacer()
                            Image(systemName: "arrow.up.left")
                                .font(.caption.weight(.semibold))
                                .foregroundColor(LegacyTheme.signal)
                        }
                        .padding(.horizontal, 14)
                        .frame(minHeight: 48)
                        .background(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(LegacyTheme.paper)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(LegacyTheme.hairline, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("empty.preset.\(preset.id)")
                }
            }
            Spacer(minLength: 18)
        }
        .frame(maxWidth: 330, alignment: .leading)
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("chat.empty")
    }
}
