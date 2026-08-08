import Foundation

/// Minimal raw-HTTP client for the Anthropic Messages API.
/// Swift has no official Anthropic SDK, so this talks to `POST /v1/messages` directly.
enum ClaudeClient {

    static let model = "claude-opus-5"
    private static let endpoint = URL(string: "https://api.anthropic.com/v1/messages")!
    private static let apiVersion = "2023-06-01"

    enum ClientError: LocalizedError {
        case noKey
        case http(Int, String)
        case refused(String)
        case malformed

        var errorDescription: String? {
            switch self {
            case .noKey:
                return "No API key. Add one from the TermDefine menu bar icon → Set API key…"
            case .http(let status, let message):
                return "Anthropic API error \(status): \(message)"
            case .refused(let category):
                return "The request was declined (\(category))."
            case .malformed:
                return "Unexpected response from the Anthropic API."
            }
        }
    }

    /// Explains `token` using what is currently on the terminal screen as context.
    static func explain(
        token: String,
        line: String,
        localDefinition: Definition?,
        snapshot: TerminalSnapshot,
        completion: @escaping (Result<String, Error>) -> Void
    ) {
        guard let key = ApiKey.current() else {
            completion(.failure(ClientError.noKey))
            return
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 600,
            // A popup wants an answer in a second or two, and the whole task is a short
            // explanation — so no thinking, and the cheapest effort level.
            "thinking": ["type": "disabled"],
            "output_config": ["effort": "low"],
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": userPrompt(token: token, line: line, local: localDefinition, snapshot: snapshot)]
            ],
        ]

        guard let data = try? JSONSerialization.data(withJSONObject: body) else {
            completion(.failure(ClientError.malformed))
            return
        }
        request.httpBody = data

        URLSession.shared.dataTask(with: request) { data, response, error in
            let result = parse(data: data, response: response, error: error)
            DispatchQueue.main.async { completion(result) }
        }.resume()
    }

    // MARK: - Response handling

    private static func parse(data: Data?, response: URLResponse?, error: Error?) -> Result<String, Error> {
        if let error { return .failure(error) }
        guard let data, let http = response as? HTTPURLResponse else {
            return .failure(ClientError.malformed)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return .failure(ClientError.malformed)
        }

        guard (200..<300).contains(http.statusCode) else {
            let message = (json["error"] as? [String: Any])?["message"] as? String ?? "unknown error"
            return .failure(ClientError.http(http.statusCode, message))
        }

        // Claude Opus 5's safety classifiers can decline a request: that arrives as a
        // successful 200 with no content, so check stop_reason before reading blocks.
        if json["stop_reason"] as? String == "refusal" {
            let category = (json["stop_details"] as? [String: Any])?["category"] as? String ?? "policy"
            return .failure(ClientError.refused(category))
        }

        let blocks = json["content"] as? [[String: Any]] ?? []
        let text = blocks
            .filter { $0["type"] as? String == "text" }
            .compactMap { $0["text"] as? String }
            .joined()
            .trimmed

        return text.isEmpty ? .failure(ClientError.malformed) : .success(text)
    }

    // MARK: - Prompts

    private static let systemPrompt = """
    You explain terminal words for a developer who just triple-clicked one in their terminal. \
    You are shown the word, the line it came from, and the visible terminal screen.

    Answer in 2–4 short sentences of plain prose. Say what the word means, then what it is \
    doing in this particular context — the specific command, flag, path, error, or Claude Code \
    session on screen. If the screen shows an error involving the word, say what caused it. \
    Skip any preamble, do not repeat the word as a heading, and do not use markdown or bullet \
    lists. Do not include internal or system XML tags in your response. If the screen gives you \
    nothing useful, just define the word.
    """

    private static func userPrompt(token: String, line: String, local: Definition?, snapshot: TerminalSnapshot) -> String {
        var parts: [String] = []
        parts.append("Word: \(token)")
        if !line.trimmed.isEmpty, line.trimmed != token {
            parts.append("Line it was clicked on: \(line.trimmed)")
        }
        parts.append("Terminal app: \(snapshot.appName)")

        if let local, local.kind != "unknown" {
            parts.append("Offline reference (may be wrong for this context): \(local.text)")
        }

        if snapshot.claudeSession {
            parts.append("""
            The screen shows an interactive Claude Code session (Anthropic's terminal coding agent). \
            Read the word in that light: it may be a slash command, a permission mode, a tool name, \
            a status line, or part of a file the agent is editing.
            """)
        }

        if !snapshot.isEmpty {
            parts.append("Visible terminal screen:\n<screen>\n\(snapshot.screen)\n</screen>")
        }

        return parts.joined(separator: "\n\n")
    }
}
