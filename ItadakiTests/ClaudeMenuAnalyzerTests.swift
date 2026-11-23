import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import Itadaki

final class ClaudeMenuAnalyzerTests: XCTestCase {
    /// Records requests and replays canned responses in order.
    private final class Stub: @unchecked Sendable {
        private let lock = NSLock()
        private var responses: [(Int, String)]
        private(set) var requests: [URLRequest] = []

        init(_ responses: [(Int, String)]) { self.responses = responses }

        var transport: ClaudeMenuAnalyzer.Transport {
            { request in
                self.lock.lock()
                defer { self.lock.unlock() }
                self.requests.append(request)
                let (status, body) = self.responses.count > 1 ? self.responses.removeFirst() : self.responses[0]
                let response = HTTPURLResponse(
                    url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
                return (Data(body.utf8), response)
            }
        }
    }

    private func reply(text: String, stopReason: String = "end_turn") -> String {
        let object: [String: Any] = [
            "type": "message", "role": "assistant", "stop_reason": stopReason,
            "content": [["type": "thinking", "thinking": ""], ["type": "text", "text": text]],
        ]
        return String(data: try! JSONSerialization.data(withJSONObject: object), encoding: .utf8)!
    }

    private func body(_ request: URLRequest) throws -> [String: Any] {
        let data = try XCTUnwrap(request.httpBody)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func testRequestShapeAndSuccess() async throws {
        let stub = Stub([(200, reply(text: MockMenuAnalyzer.fixtureJSON))])
        let analyzer = ClaudeMenuAnalyzer(apiKey: " sk-test \n", model: "", transport: stub.transport)
        let jpeg = Data([0xFF, 0xD8, 0xFF])

        let pages = try await analyzer.analyze([PageRequest(image: jpeg)])

        XCTAssertEqual(pages.count, 1)
        XCTAssertEqual(pages[0].dishes.count, 5)
        XCTAssertEqual(stub.requests.count, 1)
        let request = stub.requests[0]
        XCTAssertEqual(request.url?.absoluteString, "https://api.anthropic.com/v1/messages")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "x-api-key"), "sk-test")
        XCTAssertEqual(request.value(forHTTPHeaderField: "anthropic-version"), "2023-06-01")

        let json = try body(request)
        XCTAssertEqual(json["model"] as? String, "claude-sonnet-5-5")
        XCTAssertFalse(String(data: request.httpBody!, encoding: .utf8)!.contains("sk-test"))
        let messages = try XCTUnwrap(json["messages"] as? [[String: Any]])
        let content = try XCTUnwrap(messages[0]["content"] as? [[String: Any]])
        let source = try XCTUnwrap(content[0]["source"] as? [String: Any])
        XCTAssertEqual(content[0]["type"] as? String, "image")
        XCTAssertEqual(source["media_type"] as? String, "image/jpeg")
        XCTAssertEqual(source["data"] as? String, jpeg.base64EncodedString())
        let format = try XCTUnwrap((json["output_config"] as? [String: Any])?["format"] as? [String: Any])
        XCTAssertEqual(format["type"] as? String, "json_schema")
        XCTAssertEqual((json["output_config"] as? [String: Any])?["effort"] as? String, "low")
    }

    func testRetriesOnceWithParseError() async throws {
        let stub = Stub([
            (200, reply(text: #"{"dishes":[{"name_ja":"ラーメン"}],"notes_th":""}"#)),
            (200, reply(text: "```json\n" + MockMenuAnalyzer.fixtureJSON + "\n```")),
        ])
        let analyzer = ClaudeMenuAnalyzer(apiKey: "k", transport: stub.transport)

        let page = try await analyzer.analyzePage(PageRequest(image: Data([1])))

        XCTAssertEqual(page.dishes.count, 5)
        XCTAssertEqual(stub.requests.count, 2)
        let messages = try XCTUnwrap(try body(stub.requests[1])["messages"] as? [[String: Any]])
        XCTAssertEqual(messages.map { $0["role"] as? String }, ["user", "assistant", "user"])
        XCTAssertTrue((messages[2]["content"] as? String ?? "").contains("name_th"))
    }

    func testGivesUpAfterSecondParseFailure() async {
        let stub = Stub([(200, reply(text: "not json"))])
        let analyzer = ClaudeMenuAnalyzer(apiKey: "k", transport: stub.transport)
        do {
            _ = try await analyzer.analyzePage(PageRequest(image: Data([1])))
            XCTFail("expected failure")
        } catch MenuAnalyzerError.invalidResponse {
            XCTAssertEqual(stub.requests.count, 2)
        } catch {
            XCTFail("unexpected error \(error)")
        }
    }

    func testErrorMapping() async {
        func error(status: Int, body: String, key: String = "k") async -> MenuAnalyzerError? {
            let stub = Stub([(status, body)])
            do {
                _ = try await ClaudeMenuAnalyzer(apiKey: key, transport: stub.transport).analyze([PageRequest(image: Data([1]))])
                return nil
            } catch {
                return error as? MenuAnalyzerError
            }
        }
        let apiError = #"{"type":"error","error":{"type":"invalid_request_error","message":"bad image"}}"#
        var result = await error(status: 401, body: apiError)
        XCTAssertEqual(result, .unauthorized)
        result = await error(status: 429, body: apiError)
        XCTAssertEqual(result, .rateLimited)
        result = await error(status: 529, body: apiError)
        XCTAssertEqual(result, .overloaded)
        result = await error(status: 400, body: apiError)
        XCTAssertEqual(result, .http(status: 400, message: "bad image"))
        result = await error(status: 200, body: reply(text: "", stopReason: "refusal"))
        XCTAssertEqual(result, .refused)
        result = await error(status: 200, body: reply(text: "{", stopReason: "max_tokens"))
        XCTAssertEqual(result, .truncated)
        result = await error(status: 200, body: apiError, key: "  ")
        XCTAssertEqual(result, .missingAPIKey)
    }

    func testStripRequestSendsOverviewFirstAndThoroughEffort() async throws {
        let stub = Stub([(200, reply(text: MockMenuAnalyzer.fixtureJSON))])
        let analyzer = ClaudeMenuAnalyzer(apiKey: "k", effort: .thorough, transport: stub.transport)
        let strip = Data([1, 2]), overview = Data([3, 4])

        _ = try await analyzer.analyzePage(PageRequest(image: strip, overview: overview))

        let json = try body(stub.requests[0])
        let messages = try XCTUnwrap(json["messages"] as? [[String: Any]])
        let content = try XCTUnwrap(messages[0]["content"] as? [[String: Any]])
        XCTAssertEqual(content.map { $0["type"] as? String }, ["text", "image", "text", "image", "text"])
        let first = try XCTUnwrap(content[1]["source"] as? [String: Any])
        let second = try XCTUnwrap(content[3]["source"] as? [String: Any])
        XCTAssertEqual(first["data"] as? String, overview.base64EncodedString())
        XCTAssertEqual(second["data"] as? String, strip.base64EncodedString())
        XCTAssertEqual((json["output_config"] as? [String: Any])?["effort"] as? String, "high")
    }

    func testPagesKeepOrder() async throws {
        let stub = Stub([(200, reply(text: MockMenuAnalyzer.fixtureJSON))])
        let analyzer = ClaudeMenuAnalyzer(apiKey: "k", transport: stub.transport)
        let pages = try await analyzer.analyze((0..<7).map { PageRequest(image: Data([UInt8($0)])) })
        XCTAssertEqual(pages.count, 7)
        XCTAssertEqual(stub.requests.count, 7)
    }
}
