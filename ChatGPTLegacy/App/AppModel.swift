import Foundation
import UIKit

enum AuthPhase {
    case restoring
    case signedOut
    case requestingCode
    case waitingForBrowser(DeviceAuthorization)
    case signedIn(AccountProfile)
}

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var authPhase: AuthPhase = .restoring
    @Published private(set) var conversations: [ChatConversation]
    @Published var selectedConversationID: UUID?
    @Published private(set) var models: [CatalogModel] = []
    @Published var selectedModelID: String? {
        didSet {
            if let selectedModelID {
                defaults.set(selectedModelID, forKey: Keys.selectedModel)
            }
        }
    }
    @Published var draft = ""
    @Published private(set) var pendingAttachments: [ChatAttachment] = []
    @Published private(set) var editingMessageID: UUID?
    @Published private(set) var isGenerating = false
    @Published private(set) var isLoadingModels = false
    @Published var errorMessage: String?
    @Published private(set) var scrollSignal = UUID()

    let settings: AppSettings

    private let repository: ConversationPersisting
    private let authService: OpenAIAuthService
    private let chatService: OpenAIChatService
    private let defaults: UserDefaults
    private let isUITesting: Bool
    private var didBootstrap = false
    private var loginTask: Task<Void, Never>?
    private var generationTask: Task<Void, Never>?

    init(
        repository: ConversationPersisting = ConversationRepository(),
        authService: OpenAIAuthService = OpenAIAuthService(),
        chatService: OpenAIChatService = OpenAIChatService(),
        settings: AppSettings = AppSettings(),
        defaults: UserDefaults = .standard
    ) {
        let runningUITests = ProcessInfo.processInfo.arguments.contains("-uiTesting")
        self.repository = repository
        self.authService = authService
        self.chatService = chatService
        self.settings = settings
        self.defaults = defaults
        isUITesting = runningUITests

        let loaded = runningUITests ? [] : ((try? repository.load()) ?? [])
        let initial = loaded.isEmpty ? [ChatConversation()] : loaded
        conversations = initial
        selectedConversationID = initial.first?.id
        selectedModelID = defaults.string(forKey: Keys.selectedModel)
    }

    var activeConversation: ChatConversation? {
        guard let selectedConversationID else { return nil }
        return conversations.first { $0.id == selectedConversationID }
    }

    var activeMessages: [ChatMessage] {
        activeConversation?.messages ?? []
    }

    var currentModel: CatalogModel? {
        if let selectedModelID,
           let selected = models.first(where: { $0.id == selectedModelID }) {
            return selected
        }
        return pickerModels.first ?? models.first
    }

    var pickerModels: [CatalogModel] {
        let visible = models.filter(\.isPickerVisible)
        return visible.isEmpty ? models : visible
    }

    var sortedConversations: [ChatConversation] {
        conversations.sorted {
            if $0.isPinned != $1.isPinned { return $0.isPinned }
            return $0.updatedAt > $1.updatedAt
        }
    }

    func bootstrap() async {
        guard !didBootstrap else { return }
        didBootstrap = true

        if isUITesting {
            installUITestFixture()
            return
        }

        do {
            let tokens = try await authService.restoreValidTokens()
            authPhase = .signedIn(tokens.profile)
            await loadModels(using: tokens)
        } catch let error as OpenAIAuthError {
            if case .noSavedSession = error {
                authPhase = .signedOut
            } else {
                authPhase = .signedOut
                errorMessage = error.localizedDescription
            }
        } catch {
            authPhase = .signedOut
            errorMessage = error.localizedDescription
        }
    }

    func beginSignIn() {
        loginTask?.cancel()
        errorMessage = nil
        authPhase = .requestingCode

        loginTask = Task { [weak self] in
            guard let self else { return }
            do {
                let authorization = try await authService.beginDeviceAuthorization()
                try Task.checkCancellation()
                authPhase = .waitingForBrowser(authorization)
                let tokens = try await authService.completeDeviceAuthorization(authorization)
                try Task.checkCancellation()
                authPhase = .signedIn(tokens.profile)
                successHaptic()
                await loadModels(using: tokens)
            } catch is CancellationError {
                authPhase = .signedOut
            } catch {
                authPhase = .signedOut
                errorMessage = error.localizedDescription
                errorHaptic()
            }
        }
    }

    func cancelSignIn() {
        loginTask?.cancel()
        loginTask = nil
        authPhase = .signedOut
    }

    func signOut() {
        stopGenerating()
        loginTask?.cancel()
        if isUITesting {
            models = []
            selectedModelID = nil
            authPhase = .signedOut
            return
        }
        Task { [weak self] in
            guard let self else { return }
            do {
                try await authService.signOut()
                models = []
                selectedModelID = nil
                authPhase = .signedOut
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func refreshModels() {
        if isUITesting { return }
        Task { [weak self] in
            guard let self else { return }
            do {
                let tokens = try await authService.restoreValidTokens()
                await loadModels(using: tokens)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func selectModel(_ model: CatalogModel) {
        selectedModelID = model.id
        lightHaptic()
    }

    func selectConversation(_ id: UUID) {
        selectedConversationID = id
        editingMessageID = nil
        draft = ""
        pendingAttachments = []
    }

    func createConversation() {
        stopGenerating()
        let conversation = ChatConversation()
        conversations.append(conversation)
        selectedConversationID = conversation.id
        editingMessageID = nil
        draft = ""
        pendingAttachments = []
        persist()
        lightHaptic()
    }

    func deleteConversation(_ id: UUID) {
        if selectedConversationID == id { stopGenerating() }
        conversations.removeAll { $0.id == id }
        if conversations.isEmpty {
            conversations = [ChatConversation()]
        }
        if !conversations.contains(where: { $0.id == selectedConversationID }) {
            selectedConversationID = sortedConversations.first?.id
        }
        persist()
    }

    func renameConversation(_ id: UUID, title: String) {
        let cleaned = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        mutateConversation(id) { conversation in
            conversation.title = String(cleaned.prefix(80))
            conversation.updatedAt = Date()
        }
        persist()
    }

    func togglePin(_ id: UUID) {
        mutateConversation(id) { conversation in
            conversation.isPinned.toggle()
            conversation.updatedAt = Date()
        }
        persist()
        lightHaptic()
    }

    func applyPrompt(_ preset: PromptPreset) {
        draft = preset.prompt
        lightHaptic()
    }

    func attach(image: UIImage) {
        do {
            let attachment = try ImageAttachmentProcessor.process(image)
            guard pendingAttachments.count < 4 else {
                errorMessage = "You can attach up to four images to one message."
                return
            }
            pendingAttachments.append(attachment)
            lightHaptic()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removePendingAttachment(_ id: UUID) {
        pendingAttachments.removeAll { $0.id == id }
    }

    func beginEditing(_ message: ChatMessage) {
        guard message.role == .user else { return }
        editingMessageID = message.id
        draft = message.text
        pendingAttachments = message.attachments
        lightHaptic()
    }

    func cancelEditing() {
        editingMessageID = nil
        draft = ""
        pendingAttachments = []
    }

    func sendDraft() {
        guard !isGenerating, let conversationID = selectedConversationID else { return }
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || !pendingAttachments.isEmpty else { return }
        guard currentModel != nil else {
            errorMessage = "Load a ChatGPT model before sending."
            return
        }

        if let editingMessageID {
            mutateConversation(conversationID) { conversation in
                if let index = conversation.messages.firstIndex(where: { $0.id == editingMessageID }) {
                    conversation.messages.removeSubrange(index...)
                }
            }
        }

        let message = ChatMessage(
            role: .user,
            text: text,
            attachments: pendingAttachments
        )
        mutateConversation(conversationID) { conversation in
            conversation.messages.append(message)
            conversation.updateTitleIfNeeded(from: text.isEmpty ? "Image question" : text)
            conversation.updatedAt = Date()
        }
        draft = ""
        pendingAttachments = []
        editingMessageID = nil
        persist()
        scrollSignal = UUID()
        lightHaptic()
        generateReply(in: conversationID)
    }

    func regenerateLastResponse() {
        guard !isGenerating, let conversationID = selectedConversationID else { return }
        mutateConversation(conversationID) { conversation in
            if conversation.messages.last?.role == .assistant {
                conversation.messages.removeLast()
                conversation.updatedAt = Date()
            }
        }
        guard activeConversation?.messages.last?.role == .user else { return }
        persist()
        generateReply(in: conversationID)
    }

    func stopGenerating() {
        guard isGenerating else { return }
        generationTask?.cancel()
        generationTask = nil
        isGenerating = false
        persist()
        lightHaptic()
    }

    func dismissError() {
        errorMessage = nil
    }

    private func generateReply(in conversationID: UUID) {
        guard
            !isGenerating,
            let model = currentModel,
            let conversation = conversations.first(where: { $0.id == conversationID })
        else { return }

        let history = conversation.messages
        let assistantID = UUID()
        mutateConversation(conversationID) { conversation in
            conversation.messages.append(
                ChatMessage(id: assistantID, role: .assistant, text: "")
            )
            conversation.updatedAt = Date()
        }
        isGenerating = true
        errorMessage = nil
        scrollSignal = UUID()

        if isUITesting {
            generateUITestReply(
                assistantID: assistantID,
                conversationID: conversationID
            )
            return
        }

        let options = ChatRequestOptions(
            instructions: settings.requestInstructions,
            responseStyle: settings.responseStyle,
            reasoning: settings.reasoning
        )

        generationTask = Task { [weak self] in
            guard let self else { return }
            do {
                var tokens = try await authService.restoreValidTokens()
                do {
                    try await consumeReply(
                        history: history,
                        assistantID: assistantID,
                        conversationID: conversationID,
                        model: model,
                        options: options,
                        tokens: tokens
                    )
                } catch ChatServiceError.unauthorized where assistantText(
                    conversationID: conversationID,
                    assistantID: assistantID
                ).isEmpty {
                    tokens = try await authService.refreshSavedTokens()
                    try await consumeReply(
                        history: history,
                        assistantID: assistantID,
                        conversationID: conversationID,
                        model: model,
                        options: options,
                        tokens: tokens
                    )
                }

                if assistantText(
                    conversationID: conversationID,
                    assistantID: assistantID
                ).isEmpty {
                    removeMessage(assistantID, from: conversationID)
                    errorMessage = "OpenAI completed the request without returning text."
                } else {
                    successHaptic()
                }
            } catch is CancellationError {
                // Keep any partial response when the user taps Stop.
            } catch {
                if assistantText(
                    conversationID: conversationID,
                    assistantID: assistantID
                ).isEmpty {
                    removeMessage(assistantID, from: conversationID)
                }
                errorMessage = error.localizedDescription
                errorHaptic()
            }

            isGenerating = false
            generationTask = nil
            mutateConversation(conversationID) { $0.updatedAt = Date() }
            persist()
            scrollSignal = UUID()
        }
    }

    private func consumeReply(
        history: [ChatMessage],
        assistantID: UUID,
        conversationID: UUID,
        model: CatalogModel,
        options: ChatRequestOptions,
        tokens: OAuthTokens
    ) async throws {
        let stream = chatService.streamReply(
            messages: history,
            model: model,
            options: options,
            tokens: tokens,
            conversationID: conversationID
        )
        for try await delta in stream {
            try Task.checkCancellation()
            mutateConversation(conversationID) { conversation in
                guard let index = conversation.messages.firstIndex(
                    where: { $0.id == assistantID }
                ) else { return }
                conversation.messages[index].text += delta
            }
            scrollSignal = UUID()
        }
    }

    private func loadModels(using initialTokens: OAuthTokens) async {
        isLoadingModels = true
        defer { isLoadingModels = false }
        do {
            var tokens = initialTokens
            var fetched: [CatalogModel]
            do {
                fetched = try await chatService.fetchModels(tokens: tokens)
            } catch ChatServiceError.unauthorized {
                tokens = try await authService.refreshSavedTokens()
                fetched = try await chatService.fetchModels(tokens: tokens)
            }
            guard !fetched.isEmpty else { throw ChatServiceError.noModelAvailable }
            models = fetched

            let saved = defaults.string(forKey: Keys.selectedModel)
            if let saved, fetched.contains(where: { $0.id == saved }) {
                selectedModelID = saved
            } else {
                selectedModelID = pickerModels.first?.id ?? fetched.first?.id
            }
        } catch {
            models = []
            selectedModelID = nil
            errorMessage = error.localizedDescription
        }
    }

    private func mutateConversation(
        _ id: UUID,
        mutation: (inout ChatConversation) -> Void
    ) {
        guard let index = conversations.firstIndex(where: { $0.id == id }) else { return }
        var conversation = conversations[index]
        mutation(&conversation)
        conversations[index] = conversation
    }

    private func assistantText(conversationID: UUID, assistantID: UUID) -> String {
        conversations
            .first(where: { $0.id == conversationID })?
            .messages
            .first(where: { $0.id == assistantID })?
            .text ?? ""
    }

    private func removeMessage(_ messageID: UUID, from conversationID: UUID) {
        mutateConversation(conversationID) { conversation in
            conversation.messages.removeAll { $0.id == messageID }
        }
    }

    private func persist() {
        guard !isUITesting else { return }
        do {
            try repository.save(conversations)
        } catch {
            errorMessage = "Conversation history could not be saved: \(error.localizedDescription)"
        }
    }

    private func lightHaptic() {
        guard settings.hapticsEnabled else { return }
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    private func successHaptic() {
        guard settings.hapticsEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    private func errorHaptic() {
        guard settings.hapticsEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    private enum Keys {
        static let selectedModel = "chat.selectedModel"
    }

    private func installUITestFixture() {
        guard ProcessInfo.processInfo.arguments.contains("-uiTestSignedIn") else {
            authPhase = .signedOut
            return
        }

        let model = CatalogModel(
            slug: "gpt-ui-test",
            displayName: "GPT Premium",
            description: "Deterministic UI test model",
            defaultReasoningLevel: "medium"
        )
        models = [model]
        selectedModelID = model.id

        if ProcessInfo.processInfo.arguments.contains("-uiTestPopulated") {
            let conversation = ChatConversation(
                title: "A careful launch plan",
                messages: [
                    ChatMessage(
                        role: .user,
                        text: "Help me turn a complicated launch into a calm, practical plan."
                    ),
                    ChatMessage(
                        role: .assistant,
                        text: "Start by shrinking the launch into three proof points: **useful**, **reliable**, and **easy to recover**. Then assign one observable check to each point before expanding scope."
                    )
                ],
                isPinned: true
            )
            conversations = [conversation, ChatConversation(title: "Image notes")]
            selectedConversationID = conversation.id
        } else {
            let conversation = ChatConversation()
            conversations = [conversation]
            selectedConversationID = conversation.id
        }

        authPhase = .signedIn(
            AccountProfile(
                email: "legacy@example.com",
                plan: "plus",
                accountID: "ui-test-account"
            )
        )
    }

    func configureForVisualTesting(populated: Bool) {
        let fixtureModel = CatalogModel(
            slug: "gpt-ui-test",
            displayName: "GPT Premium",
            description: "Deterministic visual test model",
            defaultReasoningLevel: "medium"
        )
        models = [fixtureModel]
        selectedModelID = fixtureModel.id
        let messages = populated
            ? [
                ChatMessage(role: .user, text: "Give me a calm launch plan."),
                ChatMessage(
                    role: .assistant,
                    text: "Start with three proof points: **useful**, **reliable**, and **recoverable**. Give each one an observable check."
                )
            ]
            : []
        let conversation = ChatConversation(
            title: populated ? "A careful launch plan" : "New conversation",
            messages: messages
        )
        conversations = [conversation]
        selectedConversationID = conversation.id
        authPhase = .signedIn(
            AccountProfile(email: "legacy@example.com", plan: "plus", accountID: "visual")
        )
    }

    private func generateUITestReply(assistantID: UUID, conversationID: UUID) {
        let chunks = [
            "A good place to begin is to make the next step smaller. ",
            "Name the decision, the evidence you already have, and the one unknown ",
            "that would change your mind. Then test that unknown before adding complexity."
        ]
        generationTask = Task { [weak self] in
            guard let self else { return }
            for chunk in chunks {
                if Task.isCancelled { break }
                // Keep the deterministic stream observable long enough for UI
                // automation and video evidence to exercise the Stop state.
                try? await Task.sleep(nanoseconds: 750_000_000)
                if Task.isCancelled { break }
                mutateConversation(conversationID) { conversation in
                    guard let index = conversation.messages.firstIndex(
                        where: { $0.id == assistantID }
                    ) else { return }
                    conversation.messages[index].text += chunk
                }
                scrollSignal = UUID()
            }
            isGenerating = false
            generationTask = nil
            mutateConversation(conversationID) { $0.updatedAt = Date() }
            scrollSignal = UUID()
        }
    }
}
