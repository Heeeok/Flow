import SwiftUI

/// Settings view for configuring capture behavior, privacy, and LLM integration
struct SettingsView: View {
    @ObservedObject var appState: AppState

    @State private var frameRate: Double
    @State private var diffThreshold: Double
    @State private var idleCoalesce: Double
    @State private var saveThumbnails: Bool
    @State private var thumbnailWidth: String
    @State private var apiKey: String
    @State private var llmEndpoint: String
    @State private var llmModel: String
    @State private var excludedAppsText: String
    @State private var showSaved: Bool = false

    init(appState: AppState) {
        self._appState = ObservedObject(wrappedValue: appState)
        let s = appState.settings
        _frameRate = State(initialValue: s.captureFrameRate)
        _diffThreshold = State(initialValue: s.frameDiffThreshold * 100)
        _idleCoalesce = State(initialValue: s.idleCoalesceSeconds)
        _saveThumbnails = State(initialValue: s.saveThumbnails)
        _thumbnailWidth = State(initialValue: "\(s.thumbnailMaxWidth)")
        _apiKey = State(initialValue: s.llmAPIKey)
        _llmEndpoint = State(initialValue: s.llmEndpoint)
        _llmModel = State(initialValue: s.llmModel)
        _excludedAppsText = State(initialValue: s.excludedApps.joined(separator: "\n"))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Capture Settings
                settingsSection("Capture") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Frame Rate:")
                                .frame(width: 120, alignment: .trailing)
                            Slider(value: $frameRate, in: 0.5...5.0, step: 0.5)
                                .frame(width: 150)
                            Text("\(frameRate, specifier: "%.1f") fps")
                                .font(.system(size: 12, design: .monospaced))
                                .frame(width: 60)
                        }

                        HStack {
                            Text("Change Threshold:")
                                .frame(width: 120, alignment: .trailing)
                            Slider(value: $diffThreshold, in: 1...30, step: 1)
                                .frame(width: 150)
                            Text("\(Int(diffThreshold))%")
                                .font(.system(size: 12, design: .monospaced))
                                .frame(width: 60)
                        }

                        HStack {
                            Text("Idle Coalesce:")
                                .frame(width: 120, alignment: .trailing)
                            Slider(value: $idleCoalesce, in: 10...120, step: 5)
                                .frame(width: 150)
                            Text("\(Int(idleCoalesce))s")
                                .font(.system(size: 12, design: .monospaced))
                                .frame(width: 60)
                        }
                    }
                    .font(.system(size: 12))
                }

                // Privacy Settings
                settingsSection("Privacy & Storage") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 6) {
                            Image(systemName: "lock.shield.fill")
                                .foregroundColor(.green)
                            Text("Full-resolution screenshots are NEVER stored")
                                .font(.system(size: 12, weight: .medium))
                        }

                        Toggle(isOn: $saveThumbnails) {
                            Text("Save low-resolution thumbnails")
                                .font(.system(size: 12))
                        }

                        if saveThumbnails {
                            HStack {
                                Text("Max thumbnail width:")
                                    .font(.system(size: 12))
                                TextField("320", text: $thumbnailWidth)
                                    .frame(width: 60)
                                    .textFieldStyle(.roundedBorder)
                                    .font(.system(size: 12))
                                Text("px")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.leading, 20)
                        }

                        Divider()

                        Text("Sensitive content (passwords, OTP, cards, messaging) is automatically detected and blocked from storage.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }

                // Excluded Apps
                settingsSection("Excluded Apps") {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Enter bundle IDs (one per line) to exclude from capture:")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)

                        TextEditor(text: $excludedAppsText)
                            .font(.system(size: 11, design: .monospaced))
                            .frame(height: 80)
                            .border(Color.gray.opacity(0.3))
                    }
                }

                // LLM Integration
                settingsSection("LLM Integration (Optional)") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Provide an API key to enable AI-powered event summarization. Data is sent to the configured endpoint.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)

                        HStack {
                            Text("API Key:")
                                .font(.system(size: 12))
                                .frame(width: 80, alignment: .trailing)
                            SecureField("sk-...", text: $apiKey)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12))
                        }

                        HStack {
                            Text("Endpoint:")
                                .font(.system(size: 12))
                                .frame(width: 80, alignment: .trailing)
                            TextField("https://api.anthropic.com/v1/messages", text: $llmEndpoint)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11))
                        }

                        HStack {
                            Text("Model:")
                                .font(.system(size: 12))
                                .frame(width: 80, alignment: .trailing)
                            TextField("claude-sonnet-4-20250514", text: $llmModel)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 11))
                        }

                        if !apiKey.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.system(size: 11))
                                Text("API key configured")
                                    .font(.system(size: 11))
                                    .foregroundColor(.green)
                            }
                        }
                    }
                }

                // Save Button
                HStack {
                    Spacer()
                    if showSaved {
                        Text("Settings saved")
                            .font(.system(size: 12))
                            .foregroundColor(.green)
                            .transition(.opacity)
                    }
                    Button("Save Settings") {
                        saveSettings()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.regular)
                }
            }
            .padding(20)
        }
        .frame(minWidth: 460)
    }

    // MARK: - Helpers

    private func settingsSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))

            content()
                .padding(12)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
        }
    }

    private func saveSettings() {
        var s = appState.settings
        s.captureFrameRate = frameRate
        s.frameDiffThreshold = diffThreshold / 100.0
        s.idleCoalesceSeconds = idleCoalesce
        s.saveThumbnails = saveThumbnails
        s.thumbnailMaxWidth = Int(thumbnailWidth) ?? 320
        s.llmAPIKey = apiKey
        s.llmEndpoint = llmEndpoint
        s.llmModel = llmModel
        s.excludedApps = excludedAppsText
            .components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        s.save()
        appState.settings = s
        appState.applySettings()

        withAnimation {
            showSaved = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                showSaved = false
            }
        }
    }
}
