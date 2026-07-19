import XCTest
@testable import ChatGPTLegacy

final class OAuthParsingTests: XCTestCase {
    func testDecodesOpenAIIdentityAndAccessExpiration() throws {
        let now = Date().addingTimeInterval(3_600).timeIntervalSince1970
        let idToken = makeJWT([
            "email": "legacy@example.com",
            "https://api.openai.com/auth": [
                "chatgpt_plan_type": "plus",
                "chatgpt_account_id": "account-123",
                "chatgpt_account_is_fedramp": true
            ]
        ])
        let accessToken = makeJWT(["exp": now])

        let tokens = try OAuthTokens.assemble(
            idToken: idToken,
            accessToken: accessToken,
            refreshToken: "refresh"
        )

        XCTAssertEqual(tokens.email, "legacy@example.com")
        XCTAssertEqual(tokens.plan, "plus")
        XCTAssertEqual(tokens.accountID, "account-123")
        XCTAssertTrue(tokens.isFedRAMPAccount)
        XCTAssertEqual(try XCTUnwrap(tokens.expiresAt).timeIntervalSince1970, now, accuracy: 1)
    }

    func testRejectsMalformedJWT() {
        XCTAssertThrowsError(try JWTClaims.decode("not-a-jwt"))
    }

    func testDecodesStringAndLegacyDeviceCodeFields() throws {
        let modern = Data(
            #"{"device_auth_id":"device","user_code":"ABCD-1234","interval":"7"}"#.utf8
        )
        let legacy = Data(
            #"{"device_auth_id":"device","usercode":"WXYZ-9876","interval":3}"#.utf8
        )

        let decoder = JSONDecoder()
        XCTAssertEqual(try decoder.decode(DeviceUserCodeResponse.self, from: modern).interval, 7)
        XCTAssertEqual(
            try decoder.decode(DeviceUserCodeResponse.self, from: legacy).userCode,
            "WXYZ-9876"
        )
    }

    func testOAuthEndpointsRemainHTTPSAndUseCodexDevicePath() {
        XCTAssertEqual(OpenAIEndpoints.deviceVerification.scheme, "https")
        XCTAssertEqual(OpenAIEndpoints.deviceVerification.path, "/codex/device")
        XCTAssertEqual(OpenAIEndpoints.token.scheme, "https")
        XCTAssertFalse(OpenAIEndpoints.codexClientID.isEmpty)
    }

    func testDecodesSavedSessionFromBeforeFedRAMPFieldWasAdded() throws {
        let legacy = Data(
            #"{"idToken":"id","accessToken":"access","refreshToken":"refresh"}"#.utf8
        )

        let tokens = try JSONDecoder().decode(OAuthTokens.self, from: legacy)

        XCTAssertFalse(tokens.isFedRAMPAccount)
    }

    private func makeJWT(_ payload: [String: Any]) -> String {
        let header = base64URL(try! JSONSerialization.data(withJSONObject: ["alg": "none"]))
        let body = base64URL(try! JSONSerialization.data(withJSONObject: payload))
        return "\(header).\(body).signature"
    }

    private func base64URL(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
