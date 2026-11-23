import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Online analyzer: sends each page to the Claude Messages API (vision) and decodes
/// the structured JSON it returns.
struct ClaudeMenuAnalyzer: MenuAnalyzer {
    typealias Transport = @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)

    static let defaultModel = "claude-sonnet-5-5"
    /// Models offered in Settings, cheapest first. Any other model id can be typed in.
    static let knownModels: [(id: String, name: String)] = [
        ("claude-haiku-5-5", "Haiku 5.5"),
        ("claude-sonnet-5-5", "Sonnet 5.5"),
        ("claude-opus-5-5", "Opus 5.5"),
        ("claude-fable-5-2", "Fable 5.2"),
    ]
    static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    static let maxConcurrentPages = 3

    let apiKey: String
    let model: String
    let effort: AnalysisEffort
    let transport: Transport

    init(
        apiKey: String,
        model: String = ClaudeMenuAnalyzer.defaultModel,
        effort: AnalysisEffort = .low,
        transport: Transport? = nil
    ) {
        self.effort = effort
        self.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        self.model = trimmedModel.isEmpty ? ClaudeMenuAnalyzer.defaultModel : trimmedModel
        self.transport = transport ?? ClaudeMenuAnalyzer.urlSessionTransport
    }

    // MARK: MenuAnalyzer

    func analyze(_ requests: [PageRequest]) async throws -> [PageAnalysis] {
        let images = requests
        guard !apiKey.isEmpty else { throw MenuAnalyzerError.missingAPIKey }
        guard !images.isEmpty else { return [] }

        return try await withThrowingTaskGroup(of: (Int, PageAnalysis).self) { group in
            var results = [PageAnalysis?](repeating: nil, count: images.count)
            var next = 0
            func addNext() {
                let index = next
                next += 1
                group.addTask { (index, try await self.analyzePage(images[index])) }
            }
            for _ in 0..<min(Self.maxConcurrentPages, images.count) { addNext() }
            while let (index, page) = try await group.next() {
                results[index] = page
                if next < images.count { addNext() }
            }
            return results.compactMap { $0 }
        }
    }

    // MARK: One page

    func analyzePage(_ page: PageRequest) async throws -> PageAnalysis {
        func image(_ jpeg: Data) -> [String: Any] {
            [
                "type": "image",
                "source": [
                    "type": "base64",
                    "media_type": "image/jpeg",
                    "data": jpeg.base64EncodedString(),
                ],
            ]
        }
        var content: [[String: Any]]
        if let overview = page.overview {
            content = [
                ["type": "text", "text": MenuPrompt.overviewLabel],
                image(overview),
                ["type": "text", "text": MenuPrompt.stripLabel],
                image(page.image),
                ["type": "text", "text": MenuPrompt.userStrip],
            ]
        } else {
            content = [image(page.image), ["type": "text", "text": MenuPrompt.user]]
        }
        var messages: [[String: Any]] = [["role": "user", "content": content]]

        let first = try await send(messages: messages)
        do {
            return try Self.decodePage(first)
        } catch let firstError {
            // Retry once, showing the model its own output and why it failed to parse.
            messages.append(["role": "assistant", "content": first.isEmpty ? "(empty)" : first])
            messages.append([
                "role": "user",
                "content": "Your previous reply could not be parsed: \(Self.describe(firstError)). "
                    + "Reply again with only the corrected JSON object for the same menu page.",
            ])
            let second = try await send(messages: messages)
            do {
                return try Self.decodePage(second)
            } catch {
                throw MenuAnalyzerError.invalidResponse(Self.describe(error))
            }
        }
    }

    // MARK: Request / response

    func makeRequest(messages: [[String: Any]]) throws -> URLRequest {
        let body: [String: Any] = [
            "model": model,
            "max_tokens": 16000,
            "system": MenuPrompt.system,
            "messages": messages,
            "output_config": [
                // Reading a printed menu needs little deliberation, so the default is low
                // to keep the wait short; the user can raise it in Settings.
                "effort": effort.rawValue,
                "format": ["type": "json_schema", "schema": MenuPrompt.outputSchema],
            ] as [String: Any],
        ]
        var request = URLRequest(url: Self.endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 300
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        return request
    }

    /// Sends one Messages request and returns the concatenated text of the reply.
    private func send(messages: [[String: Any]]) async throws -> String {
        let request = try makeRequest(messages: messages)
        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await transport(request)
        } catch let error as MenuAnalyzerError {
            throw error
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw MenuAnalyzerError.network(error.localizedDescription)
        }

        guard (200..<300).contains(response.statusCode) else {
            let message = (try? JSONDecoder().decode(APIErrorEnvelope.self, from: data))?.error.message
                ?? "ไม่ทราบสาเหตุ"
            switch response.statusCode {
            case 401, 403: throw MenuAnalyzerError.unauthorized
            case 429: throw MenuAnalyzerError.rateLimited
            case 500...599: throw MenuAnalyzerError.overloaded
            default: throw MenuAnalyzerError.http(status: response.statusCode, message: message)
            }
        }

        guard let reply = try? JSONDecoder().decode(MessagesResponse.self, from: data) else {
            throw MenuAnalyzerError.invalidResponse("unexpected response body")
        }
        if reply.stopReason == "refusal" { throw MenuAnalyzerError.refused }
        if reply.stopReason == "max_tokens" { throw MenuAnalyzerError.truncated }
        return reply.content.compactMap { $0.type == "text" ? $0.text : nil }.joined()
    }

    // MARK: Decoding helpers

    static func decodePage(_ text: String) throws -> PageAnalysis {
        let json = extractJSONObject(from: text)
        return try JSONDecoder().decode(PageAnalysis.self, from: Data(json.utf8))
    }

    /// Returns the outermost `{ ... }` of a reply, tolerating code fences or stray prose
    /// from models that do not honour the structured output format.
    static func extractJSONObject(from text: String) -> String {
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}"), start < end else {
            return text
        }
        return String(text[start...end])
    }

    private static func describe(_ error: Error) -> String {
        switch error {
        case DecodingError.keyNotFound(let key, _):
            return "missing field \"\(key.stringValue)\""
        case DecodingError.typeMismatch(_, let context), DecodingError.valueNotFound(_, let context),
            DecodingError.dataCorrupted(let context):
            let path = context.codingPath.map(\.stringValue).joined(separator: ".")
            return path.isEmpty ? context.debugDescription : "\(path): \(context.debugDescription)"
        default:
            return error.localizedDescription
        }
    }

    private static let urlSessionTransport: Transport = { request in
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw MenuAnalyzerError.invalidResponse("not an HTTP response")
        }
        return (data, http)
    }
}

private struct MessagesResponse: Decodable {
    struct Block: Decodable {
        let type: String
        let text: String?
    }
    let content: [Block]
    let stopReason: String?

    enum CodingKeys: String, CodingKey {
        case content
        case stopReason = "stop_reason"
    }
}

private struct APIErrorEnvelope: Decodable {
    struct Detail: Decodable { let message: String }
    let error: Detail
}
