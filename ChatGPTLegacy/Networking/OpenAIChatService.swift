import Foundation

struct CatalogModel: Identifiable, Equatable, Decodable {
    let slug: String
    let displayName: String
    let description: String?
    let defaultReasoningLevel: String?
    let visibility: String
    let supportedInAPI: Bool
    let priority: Int

    var id: String { slug }
    var isPickerVisible: Bool { visibility == "list" }

    init(
        slug: String,
        displayName: String,
        description: String? = nil,
        defaultReasoningLevel: String? = nil,
        visibility: String = "list",
        supportedInAPI: Bool = true,
        priority: Int = 0
    ) {
        self.slug = slug
        self.displayName = displayName
        self.description = description
        self.defaultReasoningLevel = defaultReasoningLevel
        self.visibility = visibility
        self.supportedInAPI = supportedInAPI
        self.priority = priority
    }

    private enum CodingKeys: String, CodingKey {
        case slug
        case displayName = "display_name"
        case description
        case defaultReasoningLevel = "default_reasoning_level"
        case visibility
        case supportedInAPI = "supported_in_api"
        case priority
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        slug = try container.decode(String.self, forKey: .slug)
        displayName = try container.decodeIfPresent(String.self, forKey: .displayName) ?? slug
        description = try container.decodeIfPresent(String.self, forKey: .description)
        defaultReasoningLevel = try container.decodeIfPresent(
            String.self,
            forKey: .defaultReasoningLevel
        )
        visibility = try container.decodeIfPresent(String.self, forKey: .visibility) ?? "list"
        supportedInAPI = try container.decodeIfPresent(
            Bool.self,
            forKey: .supportedInAPI
        ) ?? true
        priority = try container.decodeIfPresent(Int.self, forKey: .priority) ?? Int.max
    }
}

struct ChatRequestOptions {
    let instructions: String
    let responseStyle: ResponseStyle
    let reasoning: ReasoningChoice
}

enum ChatServiceError: LocalizedError {
    case unauthorized
    case invalidResponse
    case invalidStream
    case noModelAvailable
    case server(status: Int?, message: String)

    var errorDescription: String? {
        switch self {
        case .unauthorized:
            return "Your ChatGPT session expired. Sign in again."
        case .invalidResponse:
            return "OpenAI returned an unexpected response."
        case .invalidStream:
            return "The response stream contained unreadable data."
        case .noModelAvailable:
            return "No model is available for this ChatGPT account."
        case .server(_, let message):
            return message
        }
    }
}

final class OpenAIChatService {
    private let session: URLSession
    private let backendBaseURL = URL(
        string: "https://chatgpt.com/backend-api/codex/"
    )!
    private let installationID: String

    init(
        session: URLSession = OpenAIChatService.makeSession(),
        defaults: UserDefaults = .standard
    ) {
        self.session = session
        let key = "client.installationID"
        if let existing = defaults.string(forKey: key) {
            installationID = existing
        } else {
            let generated = UUID().uuidString.lowercased()
            defaults.set(generated, forKey: key)
            installationID = generated
        }
    }

    func fetchModels(tokens: OAuthTokens) async throws -> [CatalogModel] {
        var components = URLComponents(
            url: backendBaseURL.appendingPathComponent("models"),
            resolvingAgainstBaseURL: false
        )!
        components.queryItems = [
            URLQueryItem(
                name: "client_version",
                value: OpenAIEndpoints.codexClientVersion
            )
        ]
        guard let url = components.url else { throw ChatServiceError.invalidResponse }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        applyHeaders(to: &request, tokens: tokens)

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        let catalog = try JSONDecoder().decode(ModelCatalogResponse.self, from: data)
        return catalog.models.sorted { lhs, rhs in
            if lhs.priority == rhs.priority { return lhs.displayName < rhs.displayName }
            return lhs.priority < rhs.priority
        }
    }

    func streamReply(
        messages: [ChatMessage],
        model: CatalogModel,
        options: ChatRequestOptions,
        tokens: OAuthTokens,
        conversationID: UUID
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let worker = Task {
                do {
                    let request = try self.makeChatRequest(
                        messages: messages,
                        model: model,
                        options: options,
                        tokens: tokens,
                        conversationID: conversationID
                    )
                    let (bytes, response) = try await self.session.bytes(for: request)
                    guard let http = response as? HTTPURLResponse else {
                        throw ChatServiceError.invalidResponse
                    }
                    guard (200..<300).contains(http.statusCode) else {
                        let data = try await Self.collect(bytes: bytes)
                        if http.statusCode == 401 {
                            throw ChatServiceError.unauthorized
                        }
                        throw ChatServiceError.server(
                            status: http.statusCode,
                            message: Self.errorMessage(from: data, status: http.statusCode)
                        )
                    }

                    var parser = SSEParser()
                    for try await line in bytes.lines {
                        try Task.checkCancellation()
                        if let event = parser.append(line: line),
                           let delta = try SSEPayload.textDelta(from: event),
                           !delta.isEmpty {
                            continuation.yield(delta)
                        }
                    }
                    if let event = parser.finish(),
                       let delta = try SSEPayload.textDelta(from: event),
                       !delta.isEmpty {
                        continuation.yield(delta)
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in worker.cancel() }
        }
    }

    private func makeChatRequest(
        messages: [ChatMessage],
        model: CatalogModel,
        options: ChatRequestOptions,
        tokens: OAuthTokens,
        conversationID: UUID
    ) throws -> URLRequest {
        let url = backendBaseURL.appendingPathComponent("responses")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.setValue(conversationID.uuidString, forHTTPHeaderField: "session-id")
        request.setValue(conversationID.uuidString, forHTTPHeaderField: "thread-id")
        request.setValue(conversationID.uuidString, forHTTPHeaderField: "x-client-request-id")
        applyHeaders(to: &request, tokens: tokens)

        let payload = Self.responsePayload(
            messages: messages,
            model: model,
            options: options,
            conversationID: conversationID
        )
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        return request
    }

    static func responsePayload(
        messages: [ChatMessage],
        model: CatalogModel,
        options: ChatRequestOptions,
        conversationID: UUID
    ) -> [String: Any] {
        var payload: [String: Any] = [
            "model": model.slug,
            "instructions": options.instructions,
            "input": responseInput(from: messages),
            "tools": [],
            "tool_choice": "auto",
            "parallel_tool_calls": false,
            "store": false,
            "stream": true,
            "include": ["reasoning.encrypted_content"],
            "prompt_cache_key": conversationID.uuidString,
            "text": ["verbosity": options.responseStyle.verbosityValue]
        ]

        let reasoningEffort = options.reasoning.apiValue ?? model.defaultReasoningLevel
        if let reasoningEffort, reasoningEffort != "none" {
            payload["reasoning"] = [
                "effort": reasoningEffort,
                "summary": "auto"
            ]
        }
        return payload
    }

    private static func responseInput(from messages: [ChatMessage]) -> [[String: Any]] {
        messages.compactMap { message in
            var content: [[String: Any]] = []
            if !message.text.isEmpty {
                content.append([
                    "type": message.role == .user ? "input_text" : "output_text",
                    "text": message.text
                ])
            }
            if message.role == .user {
                content.append(contentsOf: message.attachments.map { attachment in
                    [
                        "type": "input_image",
                        "image_url": attachment.dataURL,
                        "detail": "auto"
                    ]
                })
            }
            guard !content.isEmpty else { return nil }
            return [
                "type": "message",
                "role": message.role.rawValue,
                "content": content
            ]
        }
    }

    private func applyHeaders(to request: inout URLRequest, tokens: OAuthTokens) {
        request.setValue("Bearer \(tokens.accessToken)", forHTTPHeaderField: "Authorization")
        if let accountID = tokens.accountID {
            request.setValue(accountID, forHTTPHeaderField: "ChatGPT-Account-ID")
        }
        if tokens.isFedRAMPAccount {
            request.setValue("true", forHTTPHeaderField: "X-OpenAI-Fedramp")
        }
        request.setValue("chatgpt_legacy_ios", forHTTPHeaderField: "originator")
        request.setValue(installationID, forHTTPHeaderField: "X-Codex-Installation-Id")
        request.setValue(
            "ChatGPTLegacy/1.0.0 (iOS 15+)",
            forHTTPHeaderField: "User-Agent"
        )
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw ChatServiceError.invalidResponse
        }
        if http.statusCode == 401 { throw ChatServiceError.unauthorized }
        guard (200..<300).contains(http.statusCode) else {
            throw ChatServiceError.server(
                status: http.statusCode,
                message: Self.errorMessage(from: data, status: http.statusCode)
            )
        }
    }

    private static func collect(bytes: URLSession.AsyncBytes) async throws -> Data {
        var data = Data()
        for try await byte in bytes {
            data.append(byte)
            if data.count >= 64 * 1_024 { break }
        }
        return data
    }

    private static func errorMessage(from data: Data, status: Int) -> String {
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let error = object["error"] as? [String: Any],
               let message = error["message"] as? String {
                return message
            }
            if let detail = object["detail"] as? String { return detail }
            if let message = object["message"] as? String { return message }
        }
        if let plain = String(data: data, encoding: .utf8), !plain.isEmpty {
            return String(plain.prefix(500))
        }
        return "OpenAI returned HTTP \(status)."
    }

    private static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 60
        configuration.timeoutIntervalForResource = 15 * 60
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.waitsForConnectivity = true
        return URLSession(configuration: configuration)
    }
}

private struct ModelCatalogResponse: Decodable {
    let models: [CatalogModel]
}
