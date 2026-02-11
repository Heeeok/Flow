import SwiftUI

/// Main dashboard view with capture toggle, status, and permissions
struct DashboardView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {

            // MARK: - Capture Toggle Section
            captureToggleSection

            Divider()

            // MARK: - Status Section
            statusSection

            Divider()

            // MARK: - Permission Section
            permissionSection

            Spacer()

            // MARK: - Quick Stats
            quickStatsSection
        }
        .padding(20)
        .frame(minWidth: 340)
    }

    // MARK: - Subviews

    private var captureToggleSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Screen Capture")
                .font(.headline)

            HStack(spacing: 16) {
                Toggle(isOn: Binding(
                    get: { appState.settings.captureEnabled },
                    set: { newValue in
                        appState.settings.captureEnabled = newValue
                        appState.settings.save()
                        Task {
                            if newValue {
                                await appState.startCapture()
                            } else {
                                await appState.stopCapture()
                            }
                        }
                    }
                )) {
                    HStack(spacing: 8) {
                        StatusIndicatorView(isActive: appState.captureService.isCapturing, size: 14)
                        Text(appState.captureService.isCapturing ? "Capturing" : "Off")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(appState.captureService.isCapturing ? .primary : .secondary)
                    }
                }
                .toggleStyle(.switch)
                .tint(.green)
            }

            if let error = appState.captureService.errorMessage {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.system(size: 12))
                    Text(error)
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                        .lineLimit(2)
                }
                .padding(8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(6)
            }
        }
    }

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Status")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Last Capture")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    if let time = appState.captureService.lastCaptureTime {
                        Text(time, style: .time)
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                    } else {
                        Text("—")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Events Today")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text("\(appState.eventDetection.totalEventsToday)")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                }

                if let current = appState.eventDetection.currentEvent {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Current")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Text(current.appName)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    private var permissionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Permissions")
                .font(.subheadline)
                .foregroundColor(.secondary)

            HStack(spacing: 16) {
                PermissionBadge(
                    granted: appState.captureService.hasPermission,
                    label: "Screen Recording"
                )
                .onTapGesture {
                    appState.captureService.openScreenRecordingSettings()
                }

                PermissionBadge(
                    granted: AccessibilityService.shared.hasPermission,
                    label: "Accessibility"
                )
                .onTapGesture {
                    AccessibilityService.shared.openAccessibilitySettings()
                }
            }

            if !appState.captureService.hasPermission {
                Button("Open System Settings") {
                    appState.captureService.openScreenRecordingSettings()
                }
                .font(.system(size: 12))
                .buttonStyle(.bordered)
            }
        }
    }

    private var quickStatsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Privacy")
                .font(.system(size: 11))
                .foregroundColor(.secondary)

            HStack(spacing: 4) {
                Image(systemName: "lock.shield.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 11))
                Text("Full-resolution images are NOT stored")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            HStack(spacing: 4) {
                Image(systemName: appState.settings.saveThumbnails ? "photo.fill" : "photo")
                    .foregroundColor(appState.settings.saveThumbnails ? .orange : .green)
                    .font(.system(size: 11))
                Text(appState.settings.saveThumbnails ? "Low-res thumbnails: ON" : "Thumbnails: OFF")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }
}
