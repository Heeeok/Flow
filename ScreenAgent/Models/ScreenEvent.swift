import Foundation

/// Represents a single detected screen activity event
struct ScreenEvent: Identifiable, Codable {
    let id: String
    var timestampStart: Date
    var timestampEnd: Date
    var appBundleID: String
    var appName: String
    var windowTitle: String
    var summary: String
    var tags: [String]
    var sensitivityFlag: SensitivityLevel
    var thumbnailPath: String?
    var axTextSnippet: String?

    enum SensitivityLevel: Int, Codable, CaseIterable {
        case none = 0
        case low = 1
        case high = 2       // passwords, OTP, cards
        case blocked = 3    // content was not stored
    }

    init(
        id: String = UUID().uuidString,
        timestampStart: Date = Date(),
        timestampEnd: Date = Date(),
        appBundleID: String = "",
        appName: String = "",
        windowTitle: String = "",
        summary: String = "",
        tags: [String] = [],
        sensitivityFlag: SensitivityLevel = .none,
        thumbnailPath: String? = nil,
        axTextSnippet: String? = nil
    ) {
        self.id = id
        self.timestampStart = timestampStart
        self.timestampEnd = timestampEnd
        self.appBundleID = appBundleID
        self.appName = appName
        self.windowTitle = windowTitle
        self.summary = summary
        self.tags = tags
        self.sensitivityFlag = sensitivityFlag
        self.thumbnailPath = thumbnailPath
        self.axTextSnippet = axTextSnippet
    }

    var tagsJSON: String {
        (try? JSONEncoder().encode(tags)).flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
    }

    static func tagsFromJSON(_ json: String) -> [String] {
        guard let data = json.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([String].self, from: data)) ?? []
    }

    var durationFormatted: String {
        let seconds = Int(timestampEnd.timeIntervalSince(timestampStart))
        if seconds < 60 { return "\(seconds)s" }
        if seconds < 3600 { return "\(seconds / 60)m \(seconds % 60)s" }
        return "\(seconds / 3600)h \(seconds % 3600 / 60)m"
    }

    var timeFormatted: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: timestampStart)
    }

    var dateFormatted: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: timestampStart)
    }
}

/// User-configurable settings
struct AppSettings: Codable {
    var captureEnabled: Bool = false
    var saveThumbnails: Bool = false
    var thumbnailMaxWidth: Int = 320
    var captureFrameRate: Double = 1.0       // fps
    var frameDiffThreshold: Double = 0.05    // 5% pixel change
    var idleCoalesceSeconds: Double = 30.0   // merge events if idle
    var llmAPIKey: String = ""
    var llmEndpoint: String = "https://api.anthropic.com/v1/messages"
    var llmModel: String = "claude-sonnet-4-20250514"
    var excludedApps: [String] = []          // bundle IDs to skip

    static let defaultSettings = AppSettings()

    // MARK: - Persistence
    private static var settingsURL: URL {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ScreenAgent", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("settings.json")
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        try? data.write(to: Self.settingsURL, options: .atomic)
    }

    static func load() -> AppSettings {
        guard let data = try? Data(contentsOf: settingsURL),
              let settings = try? JSONDecoder().decode(AppSettings.self, from: data) else {
            return .defaultSettings
        }
        return settings
    }
}
