import Foundation
import ScreenCaptureKit
import CoreGraphics
import AppKit

/// Manages ScreenCaptureKit-based low-resolution frame sampling
@MainActor
final class CaptureService: ObservableObject {
    @Published var isCapturing = false
    @Published var hasPermission = false
    @Published var lastCaptureTime: Date?
    @Published var errorMessage: String?

    private var stream: SCStream?
    private var streamOutput: StreamOutputHandler?
    private var timer: Timer?
    private var settings: AppSettings

    /// Called whenever a meaningful frame is captured
    var onFrameCaptured: ((CGImage, Date) -> Void)?

    /// Called with app metadata for each capture cycle
    var onAppMetadata: ((String, String, String) -> Void)? // bundleID, appName, windowTitle

    init(settings: AppSettings = .load()) {
        self.settings = settings
    }

    // MARK: - Permission Check

    func checkPermission() async {
        do {
            // Attempting to get shareable content checks permission
            _ = try await SCShareableContent.current
            hasPermission = true
            errorMessage = nil
        } catch {
            hasPermission = false
            errorMessage = "Screen Recording permission required. Please grant it in System Settings → Privacy & Security → Screen Recording."
        }
    }

    func openScreenRecordingSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Start / Stop

    func startCapture() async {
        guard !isCapturing else { return }

        await checkPermission()
        guard hasPermission else { return }

        do {
            let content = try await SCShareableContent.current
            guard let display = content.displays.first else {
                errorMessage = "No display found"
                return
            }

            // Configure for low-resolution capture
            let config = SCStreamConfiguration()

            // Low resolution: scale down to save resources
            let scaleFactor: CGFloat = 0.25 // 1/4 resolution
            config.width = Int(display.width) / 4
            config.height = Int(display.height) / 4

            // Low frame rate: 1-2 fps as specified
            config.minimumFrameInterval = CMTime(value: 1, timescale: CMTimeScale(settings.captureFrameRate))

            // Pixel format
            config.pixelFormat = kCVPixelFormatType_32BGRA

            // Quality settings for efficiency
            config.queueDepth = 3
            config.showsCursor = false

            // Create filter: capture entire display
            let filter = SCContentFilter(display: display, excludingWindows: [])

            // Create stream
            let stream = SCStream(filter: filter, configuration: config, delegate: nil)

            // Setup output handler
            let outputHandler = StreamOutputHandler()
            outputHandler.onFrame = { [weak self] cgImage in
                Task { @MainActor in
                    self?.lastCaptureTime = Date()
                    self?.onFrameCaptured?(cgImage, Date())
                }
            }

            try stream.addStreamOutput(outputHandler, type: .screen, sampleHandlerQueue: .global(qos: .utility))

            try await stream.startCapture()

            self.stream = stream
            self.streamOutput = outputHandler
            self.isCapturing = true
            self.errorMessage = nil

            // Also start metadata collection timer
            startMetadataTimer()

            print("[Capture] Started at \(config.width)x\(config.height) @ \(settings.captureFrameRate)fps")

        } catch {
            errorMessage = "Failed to start capture: \(error.localizedDescription)"
            print("[Capture] Error: \(error)")
        }
    }

    func stopCapture() async {
        guard isCapturing else { return }

        do {
            try await stream?.stopCapture()
        } catch {
            print("[Capture] Stop error: \(error)")
        }

        stream = nil
        streamOutput = nil
        isCapturing = false
        timer?.invalidate()
        timer = nil

        print("[Capture] Stopped")
    }

    func updateSettings(_ newSettings: AppSettings) {
        self.settings = newSettings
    }

    // MARK: - Metadata Timer

    private func startMetadataTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.collectCurrentAppMetadata()
        }
    }

    private func collectCurrentAppMetadata() {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return }
        let bundleID = frontApp.bundleIdentifier ?? "unknown"
        let appName = frontApp.localizedName ?? "Unknown"

        // Get window title via CGWindow API (no AX permission needed for basic info)
        let windowTitle = Self.frontWindowTitle() ?? ""

        onAppMetadata?(bundleID, appName, windowTitle)
    }

    /// Get the title of the frontmost window using CGWindowListCopyWindowInfo
    static func frontWindowTitle() -> String? {
        guard let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }

        // Find the frontmost application's window
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return nil }
        let pid = frontApp.processIdentifier

        for window in windowList {
            guard let ownerPID = window[kCGWindowOwnerPID as String] as? Int32,
                  ownerPID == pid,
                  let layer = window[kCGWindowLayer as String] as? Int,
                  layer == 0, // Normal window layer
                  let name = window[kCGWindowName as String] as? String,
                  !name.isEmpty else { continue }
            return name
        }
        return nil
    }
}

// MARK: - Stream Output Handler

private final class StreamOutputHandler: NSObject, SCStreamOutput {
    var onFrame: ((CGImage) -> Void)?

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen else { return }
        guard sampleBuffer.isValid else { return }

        guard let imageBuffer = sampleBuffer.imageBuffer else { return }

        let ciImage = CIImage(cvImageBuffer: imageBuffer)
        let context = CIContext()

        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)

        guard let cgImage = context.createCGImage(ciImage, from: CGRect(x: 0, y: 0, width: width, height: height)) else {
            return
        }

        onFrame?(cgImage)
    }
}
