import SwiftUI

struct HistoryView: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""
    @State private var renameTarget: ChatConversation?
    @State private var shareText: ShareText?
    @State private var showSignOutConfirmation = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                searchField
                if filteredConversations.isEmpty {
                    emptyResults
                } else {
                    ScrollView {
                        LazyVStack(spacing: 9) {
                            ForEach(filteredConversations) { conversation in
                                conversationRow(conversation)
                            }
                            accountCard
                        }
                        .padding(16)
                    }
                }
            }
            .background(LegacyTheme.canvas.ignoresSafeArea())
            .navigationTitle("Conversations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("history.done")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        model.createConversation()
                        dismiss()
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .accessibilityLabel("New conversation")
                    .accessibilityIdentifier("history.new")
                }
            }
        }
        .navigationViewStyle(.stack)
        .sheet(item: $renameTarget) { conversation in
            RenameConversationView(
                initialTitle: conversation.title,
                onSave: { model.renameConversation(conversation.id, title: $0) }
            )
        }
        .sheet(item: $shareText) { payload in
            ShareSheet(items: [payload.text])
        }
        .confirmationDialog(
            "Sign out of ChatGPT?",
            isPresented: $showSignOutConfirmation,
            titleVisibility: .visible
        ) {
            Button("Sign out", role: .destructive) {
                dismiss()
                model.signOut()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Local conversations stay on this device. The OAuth session will be revoked and removed from Keychain.")
        }
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(LegacyTheme.muted)
            TextField("Search titles and messages", text: $searchText)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .focused($searchFocused)
                .submitLabel(.done)
                .onSubmit { searchFocused = false }
                .foregroundColor(LegacyTheme.ink)
                .accessibilityIdentifier("history.search")
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(LegacyTheme.faint)
                }
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 46)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(LegacyTheme.paper)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(LegacyTheme.hairline, lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private func conversationRow(_ conversation: ChatConversation) -> some View {
        HStack(spacing: 12) {
            Button {
                model.selectConversation(conversation.id)
                dismiss()
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(
                                conversation.id == model.selectedConversationID
                                    ? LegacyTheme.signalSoft
                                    : LegacyTheme.canvas
                            )
                            .frame(width: 38, height: 38)
                        Image(systemName: conversation.isPinned ? "pin.fill" : "bubble.left")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(
                                conversation.id == model.selectedConversationID
                                    ? LegacyTheme.signal
                                    : LegacyTheme.muted
                            )
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(conversation.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(LegacyTheme.ink)
                            .lineLimit(1)
                        HStack(spacing: 6) {
                            Text("\(conversation.messages.count) messages")
                            Text("·")
                            Text(conversation.updatedAt, style: .relative)
                        }
                        .font(.caption)
                        .foregroundColor(LegacyTheme.muted)
                        .lineLimit(1)
                    }
                    Spacer(minLength: 4)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("history.conversation.\(conversation.id.uuidString)")

            Menu {
                Button {
                    model.togglePin(conversation.id)
                } label: {
                    Label(
                        conversation.isPinned ? "Unpin" : "Pin",
                        systemImage: conversation.isPinned ? "pin.slash" : "pin"
                    )
                }
                Button {
                    renameTarget = conversation
                } label: {
                    Label("Rename", systemImage: "pencil")
                }
                Button {
                    shareText = ShareText(text: conversation.markdownExport)
                } label: {
                    Label("Export Markdown", systemImage: "square.and.arrow.up")
                }
                Button(role: .destructive) {
                    model.deleteConversation(conversation.id)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(LegacyTheme.muted)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Actions for \(conversation.title)")
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(LegacyTheme.paper)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(
                    conversation.id == model.selectedConversationID
                        ? LegacyTheme.signal.opacity(0.42)
                        : LegacyTheme.hairline,
                    lineWidth: 1
                )
        )
    }

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 13) {
            SectionLabel(text: "Account")
            if case .signedIn(let profile) = model.authPhase {
                HStack(spacing: 11) {
                    Circle()
                        .fill(LegacyTheme.signalSoft)
                        .frame(width: 38, height: 38)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(LegacyTheme.signal)
                        )
                    VStack(alignment: .leading, spacing: 2) {
                        Text(profile.displayName)
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(LegacyTheme.ink)
                            .lineLimit(1)
                        Text(profile.planLabel)
                            .font(.caption)
                            .foregroundColor(LegacyTheme.muted)
                    }
                    Spacer()
                    Button("Sign out") {
                        showSignOutConfirmation = true
                    }
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(LegacyTheme.warning)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
                    .accessibilityIdentifier("history.signOut")
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .fill(LegacyTheme.paper)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .stroke(LegacyTheme.hairline, lineWidth: 1)
        )
        .padding(.top, 10)
    }

    private var emptyResults: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "text.magnifyingglass")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(LegacyTheme.signal)
            Text("No matching conversations")
                .font(LegacyTheme.title)
                .foregroundColor(LegacyTheme.ink)
            Text("Try a title or phrase from a message.")
                .font(.subheadline)
                .foregroundColor(LegacyTheme.muted)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("history.noResults")
    }

    private var filteredConversations: [ChatConversation] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return model.sortedConversations }
        return model.sortedConversations.filter { conversation in
            conversation.title.localizedCaseInsensitiveContains(query) ||
                conversation.messages.contains {
                    $0.text.localizedCaseInsensitiveContains(query)
                }
        }
    }
}

private struct ShareText: Identifiable {
    let id = UUID()
    let text: String
}

private struct RenameConversationView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    let onSave: (String) -> Void

    init(initialTitle: String, onSave: @escaping (String) -> Void) {
        _title = State(initialValue: initialTitle)
        self.onSave = onSave
    }

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 14) {
                SectionLabel(text: "Conversation title")
                TextField("Title", text: $title)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityIdentifier("rename.title")
                Spacer()
            }
            .padding(20)
            .background(LegacyTheme.canvas.ignoresSafeArea())
            .navigationTitle("Rename")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onSave(title)
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityIdentifier("rename.save")
                }
            }
        }
        .navigationViewStyle(.stack)
        .presentationDetentsIfAvailable()
    }
}

private extension View {
    @ViewBuilder
    func presentationDetentsIfAvailable() -> some View {
        if #available(iOS 16.0, *) {
            presentationDetents([.medium])
        } else {
            self
        }
    }
}
