import Foundation

enum OpenAIAuthError: LocalizedError {
    case noSavedSession
    case invalidResponse
    case deviceCodeExpired
    case incompleteTokenResponse
    case server(status: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .noSavedSession:
            return "No ChatGPT sign-in is saved on this device."
        case .invalidResponse:
            return "OpenAI returned an unexpected sign-in response."
        case .deviceCodeExpired:
            return "This sign-in code expired. Start a new sign-in."
        case .incompleteTokenResponse:
            return "OpenAI did not return a complete sign-in session."
        case .server(_, let message):
            return message
        }
    }
}

actor OpenAIAuthService {
    private let session: URLSession
    private let tokenStore: OAuthTokenStoring
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(
        session: URLSession = OpenAIAuthService.makeSession(),
        tokenStore: OAuthTokenStoring = KeychainStore()
    ) {
        self.session = session
        self.tokenStore = tokenStore
    }

    func restoreValidTokens() async throws -> OAuthTokens {
        guard let tokens = try tokenStore.load() else {
            throw OpenAIAuthError.noSavedSession
        }

        if let expiration = tokens.expiresAt,
           expiration.timeIntervalSinceNow < 5 * 60 {
            return try await refresh(tokens)
        }
        return tokens
    }

    func beginDeviceAuthorization() async throws -> DeviceAuthorization {
        var request = baseRequest(url: OpenAIEndpoints.deviceUserCode, method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode([
            "client_id": OpenAIEndpoints.codexClientID
        ])

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        let payload = try decoder.decode(DeviceUserCodeResponse.self, from: data)

        return DeviceAuthorization(
            verificationURL: OpenAIEndpoints.deviceVerification,
            userCode: payload.userCode,
            expiresAt: Date().addingTimeInterval(15 * 60),
            deviceAuthID: payload.deviceAuthID,
            pollInterval: min(max(payload.interval, 1), 10)
        )
    }

    func completeDeviceAuthorization(
        _ authorization: DeviceAuthorization
    ) async throws -> OAuthTokens {
        while Date() < authorization.expiresAt {
            try Task.checkCancellation()

            var request = baseRequest(url: OpenAIEndpoints.deviceToken, method: "POST")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try encoder.encode([
                "device_auth_id": authorization.deviceAuthID,
                "user_code": authorization.userCode
            ])

            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw OpenAIAuthError.invalidResponse
            }

            if http.statusCode == 403 || http.statusCode == 404 {
                try await Task.sleep(
                    nanoseconds: UInt64(authorization.pollInterval * 1_000_000_000)
                )
                continue
            }

            try validate(response: response, data: data)
            let exchange = try decoder.decode(DeviceCodeExchangeResponse.self, from: data)
            let tokens = try await exchangeCode(exchange)
            try tokenStore.save(tokens)
            return tokens
        }

        throw OpenAIAuthError.deviceCodeExpired
    }

    func refreshSavedTokens() async throws -> OAuthTokens {
        guard let tokens = try tokenStore.load() else {
            throw OpenAIAuthError.noSavedSession
        }
        return try await refresh(tokens)
    }

    func signOut() async throws {
        if let tokens = try tokenStore.load() {
            try? await revoke(tokens)
        }
        try tokenStore.delete()
    }

    private func exchangeCode(
        _ exchange: DeviceCodeExchangeResponse
    ) async throws -> OAuthTokens {
        var request = baseRequest(url: OpenAIEndpoints.token, method: "POST")
        request.setValue(
            "application/x-www-form-urlencoded",
            forHTTPHeaderField: "Content-Type"
        )
        request.httpBody = formData([
            URLQueryItem(name: "grant_type", value: "authorization_code"),
            URLQueryItem(name: "code", value: exchange.authorizationCode),
            URLQueryItem(name: "redirect_uri", value: OpenAIEndpoints.deviceCallback),
            URLQueryItem(name: "client_id", value: OpenAIEndpoints.codexClientID),
            URLQueryItem(name: "code_verifier", value: exchange.codeVerifier)
        ])

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        let payload = try decoder.decode(OAuthTokenResponse.self, from: data)
        guard
            let idToken = payload.idToken,
            let accessToken = payload.accessToken,
            let refreshToken = payload.refreshToken
        else {
            throw OpenAIAuthError.incompleteTokenResponse
        }

        return try OAuthTokens.assemble(
            idToken: idToken,
            accessToken: accessToken,
            refreshToken: refreshToken
        )
    }

    private func refresh(_ previous: OAuthTokens) async throws -> OAuthTokens {
        var request = baseRequest(url: OpenAIEndpoints.token, method: "POST")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode([
            "client_id": OpenAIEndpoints.codexClientID,
            "grant_type": "refresh_token",
            "refresh_token": previous.refreshToken
        ])

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
        let payload = try decoder.decode(OAuthTokenResponse.self, from: data)

        let idToken = payload.idToken ?? previous.idToken
        let accessToken = payload.accessToken ?? previous.accessToken
        let refreshToken = payload.refreshToken ?? previous.refreshToken
        guard !accessToken.isEmpty, !refreshToken.isEmpty else {
            throw OpenAIAuthError.incompleteTokenResponse
        }

        let refreshed = try OAuthTokens.assemble(
            idToken: idToken,
            accessToken: accessToken,
            refreshToken: refreshToken,
            retaining: previous
        )
        try tokenStore.save(refreshed)
        return refreshed
    }

    private func revoke(_ tokens: OAuthTokens) async throws {
        var request = baseRequest(url: OpenAIEndpoints.revoke, method: "POST")
        request.timeoutInterval = 10
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode([
            "token": tokens.refreshToken,
            "token_type_hint": "refresh_token",
            "client_id": OpenAIEndpoints.codexClientID
        ])

        let (data, response) = try await session.data(for: request)
        try validate(response: response, data: data)
    }

    private func baseRequest(url: URL, method: String) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue(
            "ChatGPTLegacy/1.0.0 (iOS 15+)",
            forHTTPHeaderField: "User-Agent"
        )
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        return request
    }

    private func formData(_ items: [URLQueryItem]) -> Data? {
        var components = URLComponents()
        components.queryItems = items
        return components.percentEncodedQuery?.data(using: .utf8)
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw OpenAIAuthError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw OpenAIAuthError.server(
                status: http.statusCode,
                message: Self.errorMessage(from: data, status: http.statusCode)
            )
        }
    }

    private static func errorMessage(from data: Data, status: Int) -> String {
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let message = object["error_description"] as? String {
                return message
            }
            if let error = object["error"] as? [String: Any],
               let message = error["message"] as? String {
                return message
            }
            if let message = object["message"] as? String {
                return message
            }
        }
        return "OpenAI sign-in failed (HTTP \(status))."
    }

    private static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        configuration.timeoutIntervalForResource = 15 * 60
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.waitsForConnectivity = true
        return URLSession(configuration: configuration)
    }
}
