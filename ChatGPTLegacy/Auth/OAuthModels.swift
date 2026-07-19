import Foundation

enum OpenAIEndpoints {
    static let issuer = URL(string: "https://auth.openai.com")!
    static let deviceUserCode = URL(
        string: "https://auth.openai.com/api/accounts/deviceauth/usercode"
    )!
    static let deviceToken = URL(
        string: "https://auth.openai.com/api/accounts/deviceauth/token"
    )!
    static let deviceVerification = URL(
        string: "https://auth.openai.com/codex/device"
    )!
    static let deviceCallback = "https://auth.openai.com/deviceauth/callback"
    static let token = URL(string: "https://auth.openai.com/oauth/token")!
    static let revoke = URL(string: "https://auth.openai.com/oauth/revoke")!

    // This is the public OAuth client identifier shipped by openai/codex.
    // It is an identifier, not a secret.
    static let codexClientID = "app_EMoamEEZ73f0CkXaXp7hrann"
    static let codexClientVersion = "0.144.6"
}

struct DeviceAuthorization: Equatable {
    let verificationURL: URL
    let userCode: String
    let expiresAt: Date
    let deviceAuthID: String
    let pollInterval: TimeInterval
}

struct OAuthTokens: Codable, Equatable {
    var idToken: String
    var accessToken: String
    var refreshToken: String
    var accountID: String?
    var email: String?
    var plan: String?
    var expiresAt: Date?
    var isFedRAMPAccount: Bool

    private enum CodingKeys: String, CodingKey {
        case idToken
        case accessToken
        case refreshToken
        case accountID
        case email
        case plan
        case expiresAt
        case isFedRAMPAccount
    }

    init(
        idToken: String,
        accessToken: String,
        refreshToken: String,
        accountID: String?,
        email: String?,
        plan: String?,
        expiresAt: Date?,
        isFedRAMPAccount: Bool
    ) {
        self.idToken = idToken
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.accountID = accountID
        self.email = email
        self.plan = plan
        self.expiresAt = expiresAt
        self.isFedRAMPAccount = isFedRAMPAccount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        idToken = try container.decode(String.self, forKey: .idToken)
        accessToken = try container.decode(String.self, forKey: .accessToken)
        refreshToken = try container.decode(String.self, forKey: .refreshToken)
        accountID = try container.decodeIfPresent(String.self, forKey: .accountID)
        email = try container.decodeIfPresent(String.self, forKey: .email)
        plan = try container.decodeIfPresent(String.self, forKey: .plan)
        expiresAt = try container.decodeIfPresent(Date.self, forKey: .expiresAt)
        isFedRAMPAccount = try container.decodeIfPresent(
            Bool.self,
            forKey: .isFedRAMPAccount
        ) ?? false
    }

    var profile: AccountProfile {
        AccountProfile(email: email, plan: plan, accountID: accountID)
    }

    static func assemble(
        idToken: String,
        accessToken: String,
        refreshToken: String,
        retaining previous: OAuthTokens? = nil
    ) throws -> OAuthTokens {
        let identity = try JWTClaims.decode(idToken)
        let accessClaims = try? JWTClaims.decode(accessToken)

        return OAuthTokens(
            idToken: idToken,
            accessToken: accessToken,
            refreshToken: refreshToken,
            accountID: identity.accountID ?? previous?.accountID,
            email: identity.email ?? previous?.email,
            plan: identity.plan ?? previous?.plan,
            expiresAt: accessClaims?.expiration ?? identity.expiration ?? previous?.expiresAt,
            isFedRAMPAccount: identity.isFedRAMPAccount || (previous?.isFedRAMPAccount ?? false)
        )
    }
}

struct JWTClaims: Equatable {
    let email: String?
    let plan: String?
    let accountID: String?
    let expiration: Date?
    let isFedRAMPAccount: Bool

    static func decode(_ token: String) throws -> JWTClaims {
        let segments = token.split(separator: ".", omittingEmptySubsequences: false)
        guard segments.count == 3 else { throw JWTError.invalidFormat }

        var payload = String(segments[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = payload.count % 4
        if remainder != 0 {
            payload.append(String(repeating: "=", count: 4 - remainder))
        }

        guard
            let data = Data(base64Encoded: payload),
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw JWTError.invalidPayload
        }

        let profile = object["https://api.openai.com/profile"] as? [String: Any]
        let auth = object["https://api.openai.com/auth"] as? [String: Any]
        let expirationSeconds = (object["exp"] as? NSNumber)?.doubleValue

        return JWTClaims(
            email: (object["email"] as? String) ?? (profile?["email"] as? String),
            plan: auth?["chatgpt_plan_type"] as? String,
            accountID: auth?["chatgpt_account_id"] as? String,
            expiration: expirationSeconds.map(Date.init(timeIntervalSince1970:)),
            isFedRAMPAccount: auth?["chatgpt_account_is_fedramp"] as? Bool ?? false
        )
    }
}

enum JWTError: LocalizedError {
    case invalidFormat
    case invalidPayload

    var errorDescription: String? {
        switch self {
        case .invalidFormat:
            return "OpenAI returned a token with an invalid format."
        case .invalidPayload:
            return "OpenAI returned a token with an unreadable payload."
        }
    }
}

struct DeviceUserCodeResponse: Decodable {
    let deviceAuthID: String
    let userCode: String
    let interval: TimeInterval

    private enum CodingKeys: String, CodingKey {
        case deviceAuthID = "device_auth_id"
        case userCode = "user_code"
        case legacyUserCode = "usercode"
        case interval
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        deviceAuthID = try container.decode(String.self, forKey: .deviceAuthID)
        if let value = try container.decodeIfPresent(String.self, forKey: .userCode) {
            userCode = value
        } else {
            userCode = try container.decode(String.self, forKey: .legacyUserCode)
        }

        if let string = try? container.decode(String.self, forKey: .interval),
           let value = TimeInterval(string) {
            interval = value
        } else if let value = try? container.decode(Double.self, forKey: .interval) {
            interval = value
        } else {
            interval = 5
        }
    }
}

struct DeviceCodeExchangeResponse: Decodable {
    let authorizationCode: String
    let codeChallenge: String
    let codeVerifier: String

    private enum CodingKeys: String, CodingKey {
        case authorizationCode = "authorization_code"
        case codeChallenge = "code_challenge"
        case codeVerifier = "code_verifier"
    }
}

struct OAuthTokenResponse: Decodable {
    let idToken: String?
    let accessToken: String?
    let refreshToken: String?

    private enum CodingKeys: String, CodingKey {
        case idToken = "id_token"
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
    }
}
