import Foundation
import CoreGraphics
import AppKit

/// Orchestrates frame analysis, event cutting, and event lifecycle management.
/// Combines frame diffs with app metadata to create meaningful ScreenEvents.
@MainActor
final class EventDetectionService: ObservableObject {
    @Published var currentEvent: ScreenEvent?
    @Published var totalEventsToday: Int = 0

    private let diffEngine: FrameDiffEngine
    private let sensitivityDetector = SensitivityDetector()
    private var settings: AppSettings
    private var previousFrame: CGImage?
    private var lastSignificantChange: Date = Date()
    private var lastAppBundle: String = ""
    private var lastWindowTitle: String = ""
    private var framesSinceLastEvent: Int = 0
    private var coalesceTimer: Timer?

    init(settings: AppSettings = .load()) {
        self.settings = settings
        self.diffEngine = FrameDiffEngine(threshold: settings.frameDiffThreshold)
    }

    // MARK: - Frame Processing Pipeline

    /// Process a new captured frame + current app metadata
    func processFrame(_ frame: CGImage, appBundle: String, appName: String, windowTitle: String) {
        // Check if this app is excluded
        guard !settings.excludedApps.contains(appBundle) else { return }

        // Check for blank/lock screen
        if diffEngine.isBlankScreen(frame) {
            finalizeCurrentEventIfNeeded(reason: "blank_screen")
            previousFrame = frame
            return
        }

        // Check sensitivity
        let sensitivity = sensitivityDetector.assessFromMetadata(
            appBundle: appBundle,
            windowTitle: windowTitle
        )

        if sensitivity == .blocked {
            // Don't store content, just log that sensitive screen was detected
            finalizeCurrentEventIfNeeded(reason: "sensitive_content")
            logSensitiveEvent(appBundle: appBundle, appName: appName)
            previousFrame = frame
            return
        }

        // Detect app switch
        let appSwitched = appBundle != lastAppBundle || windowTitle != lastWindowTitle

        // Compute frame diff
        var isSignificantChange = false
        if let prev = previousFrame {
            let diff = diffEngine.compare(prev, frame)
            isSignificantChange = diff.isSignificant
        } else {
            isSignificantChange = true // First frame is always significant
        }

        // Event cutting logic
        if appSwitched {
            // App switch → finalize current event and start new one
            finalizeCurrentEventIfNeeded(reason: "app_switch")
            startNewEvent(
                frame: frame,
                appBundle: appBundle,
                appName: appName,
                windowTitle: windowTitle,
                sensitivity: sensitivity
            )
        } else if isSignificantChange {
            // Same app but significant visual change
            framesSinceLastEvent += 1
            lastSignificantChange = Date()

            if currentEvent == nil {
                startNewEvent(
                    frame: frame,
                    appBundle: appBundle,
                    appName: appName,
                    windowTitle: windowTitle,
                    sensitivity: sensitivity
                )
            } else {
                // Update current event's end time and window title
                currentEvent?.timestampEnd = Date()
                if windowTitle != currentEvent?.windowTitle && !windowTitle.isEmpty {
                    currentEvent?.windowTitle = windowTitle
                }
            }

            // Reset coalesce timer
            resetCoalesceTimer()
        } else {
            // No significant change — check if we should coalesce
            framesSinceLastEvent += 1
        }

        // Update tracking state
        previousFrame = frame
        lastAppBundle = appBundle
        lastWindowTitle = windowTitle
    }

    /// Process app metadata update (called more frequently than frames)
    func processAppMetadata(bundleID: String, appName: String, windowTitle: String) {
        if bundleID != lastAppBundle {
            // App switch detected from metadata alone
            processAppSwitch(bundleID: bundleID, appName: appName, windowTitle: windowTitle)
        }
    }

    // MARK: - Event Lifecycle

    private func startNewEvent(
        frame: CGImage,
        appBundle: String,
        appName: String,
        windowTitle: String,
        sensitivity: ScreenEvent.SensitivityLevel
    ) {
        let now = Date()

        // Generate summary from metadata
        let summary = generateSummary(appName: appName, windowTitle: windowTitle)
        let tags = generateTags(appBundle: appBundle, windowTitle: windowTitle)

        var event = ScreenEvent(
            timestampStart: now,
            timestampEnd: now,
            appBundleID: appBundle,
            appName: appName,
            windowTitle: windowTitle,
            summary: summary,
            tags: tags,
            sensitivityFlag: sensitivity
        )

        // Save thumbnail if enabled and not sensitive
        if settings.saveThumbnails && sensitivity == .none {
            event.thumbnailPath = saveThumbnail(frame, eventID: event.id)
        }

        currentEvent = event
        framesSinceLastEvent = 0
        lastSignificantChange = now
    }

    private func finalizeCurrentEventIfNeeded(reason: String) {
        guard var event = currentEvent else { return }

        event.timestampEnd = Date()

        // Only save events longer than 1 second
        if event.timestampEnd.timeIntervalSince(event.timestampStart) >= 1.0 {
            DatabaseService.shared.insertEvent(event)
            totalEventsToday = DatabaseService.shared.todayEventCount()
        }

        currentEvent = nil
    }

    private func processAppSwitch(bundleID: String, appName: String, windowTitle: String) {
        finalizeCurrentEventIfNeeded(reason: "app_switch_meta")

        let sensitivity = sensitivityDetector.assessFromMetadata(
            appBundle: bundleID,
            windowTitle: windowTitle
        )

        if sensitivity != .blocked {
            let summary = generateSummary(appName: appName, windowTitle: windowTitle)
            let tags = generateTags(appBundle: bundleID, windowTitle: windowTitle)

            let event = ScreenEvent(
                timestampStart: Date(),
                timestampEnd: Date(),
                appBundleID: bundleID,
                appName: appName,
                windowTitle: windowTitle,
                summary: summary,
                tags: tags,
                sensitivityFlag: sensitivity
            )
            currentEvent = event
        }

        lastAppBundle = bundleID
        lastWindowTitle = windowTitle
    }

    private func logSensitiveEvent(appBundle: String, appName: String) {
        let event = ScreenEvent(
            timestampStart: Date(),
            timestampEnd: Date(),
            appBundleID: appBundle,
            appName: appName,
            windowTitle: "[Sensitive — not recorded]",
            summary: "Sensitive screen detected",
            tags: ["sensitive"],
            sensitivityFlag: .blocked
        )
        DatabaseService.shared.insertEvent(event)
        totalEventsToday = DatabaseService.shared.todayEventCount()
    }

    // MARK: - Coalesce Timer

    private func resetCoalesceTimer() {
        coalesceTimer?.invalidate()
        coalesceTimer = Timer.scheduledTimer(
            withTimeInterval: settings.idleCoalesceSeconds,
            repeats: false
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.finalizeCurrentEventIfNeeded(reason: "idle_coalesce")
            }
        }
    }

    // MARK: - Summary & Tag Generation (Local Heuristics)

    private func generateSummary(appName: String, windowTitle: String) -> String {
        if windowTitle.isEmpty {
            return "Using \(appName)"
        }

        // Clean up common patterns
        var title = windowTitle

        // Remove common suffixes
        let suffixes = [" — Mozilla Firefox", " - Google Chrome", " – Safari", " - Safari",
                        " - Visual Studio Code", " — Visual Studio Code"]
        for suffix in suffixes {
            if title.hasSuffix(suffix) {
                title = String(title.dropLast(suffix.count))
            }
        }

        return "\(appName): \(title)"
    }

    private func generateTags(appBundle: String, windowTitle: String) -> [String] {
        var tags: [String] = []

        // Category from bundle ID
        let bundleLower = appBundle.lowercased()
        let titleLower = windowTitle.lowercased()

        if bundleLower.contains("browser") || bundleLower.contains("safari") ||
           bundleLower.contains("chrome") || bundleLower.contains("firefox") ||
           bundleLower.contains("webkit") {
            tags.append("browsing")
        }

        if bundleLower.contains("terminal") || bundleLower.contains("iterm") ||
           bundleLower.contains("warp") || bundleLower.contains("alacritty") {
            tags.append("terminal")
        }

        if bundleLower.contains("code") || bundleLower.contains("xcode") ||
           bundleLower.contains("intellij") || bundleLower.contains("sublime") ||
           bundleLower.contains("vim") || bundleLower.contains("cursor") {
            tags.append("coding")
        }

        if bundleLower.contains("mail") || bundleLower.contains("outlook") ||
           titleLower.contains("inbox") || titleLower.contains("mail") {
            tags.append("email")
        }

        if bundleLower.contains("slack") || bundleLower.contains("discord") ||
           bundleLower.contains("teams") || bundleLower.contains("zoom") ||
           bundleLower.contains("messages") {
            tags.append("communication")
        }

        if bundleLower.contains("finder") || bundleLower.contains("pathfinder") {
            tags.append("files")
        }

        if bundleLower.contains("pages") || bundleLower.contains("word") ||
           bundleLower.contains("docs") || bundleLower.contains("notion") ||
           bundleLower.contains("obsidian") || bundleLower.contains("bear") {
            tags.append("writing")
        }

        if bundleLower.contains("figma") || bundleLower.contains("sketch") ||
           bundleLower.contains("photoshop") || bundleLower.contains("preview") {
            tags.append("design")
        }

        // Keyword-based tags from window title
        if titleLower.contains("error") || titleLower.contains("exception") ||
           titleLower.contains("failed") || titleLower.contains("crash") {
            tags.append("error")
        }

        if titleLower.contains("settings") || titleLower.contains("preferences") ||
           titleLower.contains("configuration") {
            tags.append("settings")
        }

        if titleLower.contains("search") || titleLower.contains("google") {
            tags.append("search")
        }

        if tags.isEmpty {
            tags.append("general")
        }

        return tags
    }

    // MARK: - Thumbnail

    private func saveThumbnail(_ image: CGImage, eventID: String) -> String? {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ScreenAgent/thumbnails", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let url = dir.appendingPathComponent("\(eventID).jpg")

        // Resize to thumbnail
        let maxWidth = CGFloat(settings.thumbnailMaxWidth)
        let scale = min(maxWidth / CGFloat(image.width), 1.0)
        let newWidth = Int(CGFloat(image.width) * scale)
        let newHeight = Int(CGFloat(image.height) * scale)

        guard let colorSpace = image.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB),
              let context = CGContext(
                data: nil,
                width: newWidth,
                height: newHeight,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
              ) else { return nil }

        context.interpolationQuality = .low
        context.draw(image, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))

        guard let resized = context.makeImage() else { return nil }

        let bitmapRep = NSBitmapImageRep(cgImage: resized)
        guard let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.5]) else { return nil }

        do {
            try jpegData.write(to: url)
            return url.path
        } catch {
            print("[Thumbnail] Save error: \(error)")
            return nil
        }
    }

    // MARK: - Cleanup

    func flush() {
        finalizeCurrentEventIfNeeded(reason: "flush")
        coalesceTimer?.invalidate()
    }

    func updateSettings(_ newSettings: AppSettings) {
        self.settings = newSettings
    }

    func refreshTodayCount() {
        totalEventsToday = DatabaseService.shared.todayEventCount()
    }
}
