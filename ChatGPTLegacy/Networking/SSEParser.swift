import Foundation

struct SSEEvent: Equatable {
    let name: String?
    let data: String
}

struct SSEParser {
    private var eventName: String?
    private var dataLines: [String] = []

    mutating func append(line: String) -> SSEEvent? {
        if line.isEmpty {
            return emit()
        }
        if line.hasPrefix(":") {
            return nil
        }

        let parts = line.split(
            separator: ":",
            maxSplits: 1,
            omittingEmptySubsequences: false
        )
        let field = String(parts[0])
        var value = parts.count > 1 ? String(parts[1]) : ""
        if value.hasPrefix(" ") { value.removeFirst() }

        switch field {
        case "event":
            eventName = value
        case "data":
            dataLines.append(value)
        default:
            break
        }
        return nil
    }

    mutating func finish() -> SSEEvent? {
        emit()
    }

    private mutating func emit() -> SSEEvent? {
        defer {
            eventName = nil
            dataLines.removeAll(keepingCapacity: true)
        }
        guard !dataLines.isEmpty else { return nil }
        return SSEEvent(name: eventName, data: dataLines.joined(separator: "\n"))
    }
}

enum SSEPayload {
    static func textDelta(from event: SSEEvent) throws -> String? {
        guard event.data != "[DONE]" else { return nil }
        guard
            let data = event.data.data(using: .utf8),
            let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw ChatServiceError.invalidStream
        }

        let type = (object["type"] as? String) ?? event.name
        if type == "response.output_text.delta" {
            return object["delta"] as? String
        }

        if type == "error" || type == "response.failed" {
            if let message = nestedErrorMessage(in: object) {
                throw ChatServiceError.server(status: nil, message: message)
            }
            throw ChatServiceError.server(
                status: nil,
                message: "OpenAI could not complete this response."
            )
        }
        return nil
    }

    private static func nestedErrorMessage(in object: [String: Any]) -> String? {
        if let error = object["error"] as? [String: Any],
           let message = error["message"] as? String {
            return message
        }
        if let response = object["response"] as? [String: Any],
           let error = response["error"] as? [String: Any],
           let message = error["message"] as? String {
            return message
        }
        return object["message"] as? String
    }
}
