# ScreenAgent
**Work In Progress (WIP)**

ScreenAgent is a macOS-native screen awareness agent built with SwiftUI and ScreenCaptureKit.

It observes on-screen activity, detects meaningful events, and optionally hands structured summaries to an external LLM.

---

## Overview

- Detects what process the user is currently working on
- Records meaningful screen events
- Optionally integrates with external LLM APIs

---

## Architecture

ScreenAgent/
├── project.yml  
├── setup.sh  
├── README.md  
└── ScreenAgent/  
  ├── App/  
  │  ├── ScreenAgentApp.swift  
  │  └── AppState.swift  
  ├── Models/  
  │  └── ScreenEvent.swift  
  ├── Services/  
  │  ├── CaptureService.swift  
  │  ├── FrameDiffEngine.swift  
  │  ├── EventDetectionService.swift  
  │  ├── DatabaseService.swift  
  │  ├── AccessibilityService.swift  
  │  ├── SensitivityDetector.swift  
  │  └── LLMService.swift  
  ├── Views/  
  │  ├── MainView.swift  
  │  ├── DashboardView.swift  
  │  ├── SearchView.swift  
  │  ├── EventDetailView.swift  
  │  ├── SettingsView.swift  
  │  ├── StatusIndicatorView.swift  
  │  └── MenuBarView.swift  
  └── Resources/  
    └── Info.plist  

---

## Requirements

- macOS 13.0+
- Xcode 15.0+
- XcodeGen (recommended)

Install:

```bash
brew install xcodegen
```

---

## Build

### Option 1 (Recommended)

```bash
brew install xcodegen
cd ScreenAgent
./setup.sh
```

### Option 2

```bash
xcodegen generate
open ScreenAgent.xcodeproj
```

Run with ⌘R.

---

## Permissions

### Screen Recording (Required)

System Settings → Privacy & Security → Screen Recording → Enable ScreenAgent

### Accessibility (Optional)

System Settings → Privacy & Security → Accessibility → Enable ScreenAgent

---

## Data Pipeline

ScreenCaptureKit (1–2 fps, low resolution)  
↓  
FrameDiffEngine (pixel change detection)  
↓  
EventDetectionService  
- App switch → new event  
- Large change → update  
- No change (30s) → close  
- Sensitive content → block  
↓  
SQLite database  

Database location:

~/Library/Application Support/ScreenAgent/screenagent.db

---

## Privacy

- Full-resolution screenshots: NOT stored
- Thumbnails: optional (default OFF)
- Sensitive screens auto-detected and blocked
- LLM requires manual API key
- Sensitive events never sent to LLM

---

## SQLite Schema

```sql
CREATE TABLE events (
    id TEXT PRIMARY KEY,
    ts_start REAL NOT NULL,
    ts_end REAL NOT NULL,
    app_bundle TEXT NOT NULL DEFAULT '',
    app_name TEXT NOT NULL DEFAULT '',
    window_title TEXT NOT NULL DEFAULT '',
    summary TEXT NOT NULL DEFAULT '',
    tags_json TEXT NOT NULL DEFAULT '[]',
    sensitivity_flag INTEGER NOT NULL DEFAULT 0,
    thumb_path TEXT,
    ax_text_snippet TEXT
);
```

---

## Troubleshooting

- Screen Recording error → Enable permission
- Signing error → Use "Sign to Run Locally"
- No events saved → Ensure capture toggle is ON
- XcodeGen not found → Install via brew

---

## License

Internal development stage.
