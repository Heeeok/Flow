import Foundation

/// Optional LLM integration for enhanced event summarization.
/// Users provide their own API key; all calls are opt-in.
final class LLMService {
    static let shared = LLMService()

    private var settings: AppSettings = .load()

    var isConfigured: Bool {
        !settings.llmAPIKey.isEmpty
    }

    func updateSettings(_ newSettings: AppSettings) {
        self.settings = newSettings
    }

    // MARK: - Summarize Event

    /// Enhance an event's summary using the configured LLM
    func enhanceSummary(for event: ScreenEvent) async -> String? {
        guard isConfigured else { return nil }
        guard event.sensitivityFlag == .none else { return nil } // Never send sensitive data

        let prompt = """
        Based on the following screen activity metadata, provide a concise 1-sentence summary of what the user was doing:

        App: \(event.appName)
        Window Title: \(event.windowTitle)
        Duration: \(event.durationFormatted)
        Tags: \(event.tags.joined(separator: ", "))
        \(event.axTextSnippet.map { "Visible Text: \($0.prefix(500))" } ?? "")

        Respond with ONLY the summary sentence, no explanations.
        """

        return await callAPI(prompt: prompt)
    }

    /// Batch summarize a day's events into a daily digest
    func generateDailySummary(events: [ScreenEvent]) async -> String? {
        guard isConfigured else { return nil }

        // Filter out sensitive events
        let safeEvents = events.filter { $0.sensitivityFlag == .none }
        guard !safeEvents.isEmpty else { return nil }

        let eventDescriptions = safeEvents.prefix(50).map { event in
            "[\(event.timeFormatted)] \(event.appName): \(event.windowTitle) (\(event.durationFormatted))"
        }.joined(separator: "\n")

        let prompt = """
        Based on the following screen activity log, provide a brief daily summary of what the user worked on. Group by activity type and highlight key tasks.

        Activity Log:
        \(eventDescriptions)

        Provide a concise summary (3-5 bullet points).
        """

        return await callAPI(prompt: prompt)
    }

    // MARK: - API Call

    private func callAPI(prompt: String) async -> String? {
        guard let url = URL(string: settings.llmEndpoint) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(settings.llmAPIKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": settings.llmModel,
            "max_tokens": 256,
            "messages": [
                ["role": "user", "content": prompt]
            ]
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else { return nil }
        request.httpBody = jsonData
        request.timeoutInterval = 30

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("[LLM] API error: \((response as? HTTPURLResponse)?.statusCode ?? -1)")
                return nil
            }

            // Parse Anthropic response
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let content = json["content"] as? [[String: Any]],
               let firstBlock = content.first,
               let text = firstBlock["text"] as? String {
                return text.trimmingCharacters(in: .whitespacesAndNewlines)
            }

            return nil
        } catch {
            print("[LLM] Request error: \(error)")
            return nil
        }
    }
}
