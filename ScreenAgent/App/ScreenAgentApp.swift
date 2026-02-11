import SwiftUI

@main
struct ScreenAgentApp: App {
    @StateObject private var appState = AppState()
    @Environment(\.openWindow) private var openWindow

    var body: some Scene {
        // Main Window
        WindowGroup {
            MainView(appState: appState)
                .task {
                    await appState.resumeIfNeeded()
                }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 800, height: 560)

        // Menu Bar Extra
        MenuBarExtra {
            MenuBarView(appState: appState)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: appState.captureService.isCapturing ? "eye.fill" : "eye.slash")
            }
        }
        .menuBarExtraStyle(.window)

        // Settings Window
        Settings {
            SettingsView(appState: appState)
                .frame(width: 520, height: 600)
        }
    }
}
