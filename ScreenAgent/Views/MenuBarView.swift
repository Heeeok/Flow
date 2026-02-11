import SwiftUI

/// Menu bar dropdown view with quick controls and recent events
struct MenuBarView: View {
    @ObservedObject var appState: AppState
    @State private var recentEvents: [ScreenEvent] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("ScreenAgent")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                StatusIndicatorView(isActive: appState.captureService.isCapturing, size: 10)
                Text(appState.captureService.isCapturing ? "ON" : "OFF")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(appState.captureService.isCapturing ? .green : .secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            // Quick Toggle
            Button(action: {
                Task {
                    await appState.toggleCapture()
                }
            }) {
                HStack {
                    Image(systemName: appState.captureService.isCapturing ? "pause.circle.fill" : "play.circle.fill")
                        .foregroundColor(appState.captureService.isCapturing ? .orange : .green)
                    Text(appState.captureService.isCapturing ? "Pause Capture" : "Start Capture")
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider()

            // Stats
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Today")
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    Text("\(appState.eventDetection.totalEventsToday) events")
                        .font(.system(size: 11, weight: .medium))
                }

                if let lastTime = appState.captureService.lastCaptureTime {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Last")
                            .font(.system(size: 9))
                            .foregroundColor(.secondary)
                        Text(lastTime, style: .time)
                            .font(.system(size: 11, design: .monospaced))
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)

            Divider()

            // Recent Events
            if !recentEvents.isEmpty {
                Text("Recent Events")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.top, 6)

                ForEach(recentEvents.prefix(5)) { event in
                    HStack(spacing: 6) {
                        Text(event.timeFormatted)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(.secondary)
                        Text(event.appName)
                            .font(.system(size: 11, weight: .medium))
                            .lineLimit(1)
                        Spacer()
                        Text(event.durationFormatted)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 3)
                }
            }

            Divider()

            // Quit
            Button(action: {
                Task {
                    await appState.stopCapture()
                    NSApplication.shared.terminate(nil)
                }
            }) {
                HStack {
                    Text("Quit ScreenAgent")
                    Spacer()
                    Text("⌘Q")
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .keyboardShortcut("q", modifiers: .command)
        }
        .frame(width: 280)
        .padding(.vertical, 4)
        .onAppear {
            recentEvents = DatabaseService.shared.recentEvents(limit: 5)
        }
    }
}
