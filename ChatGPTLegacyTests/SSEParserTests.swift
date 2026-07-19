import XCTest
@testable import ChatGPTLegacy

final class SSEParserTests: XCTestCase {
    func testParsesNamedMultilineEvent() {
        var parser = SSEParser()
        XCTAssertNil(parser.append(line: ": keepalive"))
        XCTAssertNil(parser.append(line: "event: response.output_text.delta"))
        XCTAssertNil(parser.append(line: "data: {\"delta\":\"Hello\","))
        XCTAssertNil(parser.append(line: "data: \"type\":\"response.output_text.delta\"}"))

        let event = parser.append(line: "")
        XCTAssertEqual(event?.name, "response.output_text.delta")
        XCTAssertEqual(
            event?.data,
            "{\"delta\":\"Hello\",\n\"type\":\"response.output_text.delta\"}"
        )
    }

    func testExtractsOutputTextDelta() throws {
        let event = SSEEvent(
            name: nil,
            data: #"{"type":"response.output_text.delta","delta":"Legacy"}"#
        )
        XCTAssertEqual(try SSEPayload.textDelta(from: event), "Legacy")
    }

    func testSurfacesNestedStreamError() {
        let event = SSEEvent(
            name: "response.failed",
            data: #"{"type":"response.failed","response":{"error":{"message":"Model unavailable"}}}"#
        )
        XCTAssertThrowsError(try SSEPayload.textDelta(from: event)) { error in
            XCTAssertEqual(error.localizedDescription, "Model unavailable")
        }
    }

    func testFinishFlushesEventWithoutTrailingBlankLine() {
        var parser = SSEParser()
        XCTAssertNil(parser.append(line: "data: [DONE]"))
        XCTAssertEqual(parser.finish(), SSEEvent(name: nil, data: "[DONE]"))
    }
}
