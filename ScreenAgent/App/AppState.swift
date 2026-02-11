import Foundation
import SwiftUI

/// Central application state that coordinates all services
@MainActor
final class AppState: ObservableObject {
    @Published var settings: AppSettings
    @Published var captureService: CaptureService
    @Published var eventDetection: EventDetectionService

    init() {
        let loadedSettings = AppSettings.load()
        self.settings = loadedSettings
        self.captureService = CaptureService(settings: loadedSettings)
        self.eventDetection = EventDetectionService(settings: loadedSettings)

        setupPipeline()
    }

    // MARK: - Pipeline Setup

    /// Wire up the capture → diff → event detection pipeline
    private func setupPipeline() {
        // When a frame is captured, feed it to event detection
        captureService.onFrameCaptured = { [weak self] cgImage, timestamp in
            guard let self = self else { return }
            guard let frontApp = NSWorkspace.shared.frontmostApplication else { return }

            let bundleID = frontApp.bundleIdentifier ?? "unknown"
            let appName = frontApp.localizedName ?? "Unknown"
            let windowTitle = CaptureService.frontWindowTitle() ?? ""

            self.eventDetection.processFrame(
                cgImage,
                appBundle: bundleID,
                appName: appName,
                windowTitle: windowTitle
            )
        }

        // App metadata updates (more frequent, no frame needed)
        captureService.onAppMetadata = { [weak self] bundleID, appName, windowTitle in
            Task { @MainActor [weak self] in
                self?.eventDetection.processAppMetadata(
                    bundleID: bundleID,
                    appName: appName,
                    windowTitle: windowTitle
                )
            }
        }
    }

    // MARK: - Capture Control

    func startCapture() async {
        await captureService.startCapture()
    }

    func stopCapture() async {
        eventDetection.flush()
        await captureService.stopCapture()
    }

    func toggleCapture() async {
        if captureService.isCapturing {
            await stopCapture()
            settings.captureEnabled = false
        } else {
            settings.captureEnabled = true
            await startCapture()
        }
        settings.save()
    }

    // MARK: - Settings

    func applySettings() {
        captureService.updateSettings(settings)
        eventDetection.updateSettings(settings)
        LLMService.shared.updateSettings(settings)
    }

    // MARK: - Resume on Launch

    func resumeIfNeeded() async {
        if settings.captureEnabled {
            await startCapture()
        }
    }
}
