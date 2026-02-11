# ScreenAgent
**WIP**

1. Records & Determines what process the user is currently working on.
2. Handover composed on-screen information to LLM
## 아키텍처

```
ScreenAgent/
├── project.yml                      # XcodeGen 프로젝트 정의
├── setup.sh                         # 빌드 스크립트
├── README.md
└── ScreenAgent/
    ├── App/
    │   ├── ScreenAgentApp.swift      # @main 앱 진입점 + MenuBarExtra
    │   └── AppState.swift            # 중앙 상태 관리 (ObservableObject)
    ├── Models/
    │   └── ScreenEvent.swift         # 이벤트 모델 + AppSettings
    ├── Services/
    │   ├── CaptureService.swift      # ScreenCaptureKit 저해상도 프레임 샘플링
    │   ├── FrameDiffEngine.swift     # 프레임 간 픽셀 변화량 계산
    │   ├── EventDetectionService.swift # 이벤트 컷팅 + 세션 관리
    │   ├── DatabaseService.swift     # SQLite CRUD + 검색
    │   ├── AccessibilityService.swift # AX API 텍스트 추출 (옵션)
    │   ├── SensitivityDetector.swift  # 민감정보 감지 + 차단
    │   └── LLMService.swift          # 외부 LLM 연동 (옵션, API 키 필요)
    ├── Views/
    │   ├── MainView.swift            # NavigationSplitView 루트
    │   ├── DashboardView.swift       # 토글 + LED 표시등 + 상태
    │   ├── SearchView.swift          # 키워드/날짜 검색 + 결과 리스트
    │   ├── EventDetailView.swift     # 이벤트 상세 (시간/요약/태그/썸네일)
    │   ├── SettingsView.swift        # 설정 (캡처/프라이버시/LLM)
    │   ├── StatusIndicatorView.swift  # LED 스타일 표시등
    │   └── MenuBarView.swift         # 메뉴바 드롭다운
    └── Resources/
        └── Info.plist                # 권한 설명 문자열 포함
```

## 요구사항

- macOS 13.0 이상
- Xcode 15.0 이상
- XcodeGen (권장): `brew install xcodegen`

## 빌드 방법

### 방법 1: 스크립트 사용 (XcodeGen 필요)

```bash
brew install xcodegen    # 최초 1회
cd ScreenAgent
./setup.sh
```

### 방법 2: Xcode에서 직접

1. `xcodegen generate` 실행하여 .xcodeproj 생성
2. Xcode에서 `ScreenAgent.xcodeproj` 열기
3. Scheme → ScreenAgent 선택
4. ⌘R 로 실행

### 방법 3: Xcode 프로젝트 수동 생성

1. Xcode → File → New → Project → macOS → App
2. Product Name: `ScreenAgent`, Interface: SwiftUI, Language: Swift
3. 자동 생성된 ContentView.swift 삭제
4. `ScreenAgent/` 폴더의 모든 파일을 프로젝트로 드래그
5. Build Settings:
   - Deployment Target: macOS 13.0
   - Code Sign Identity: Sign to Run Locally
   - Entitlements: `ScreenAgent/ScreenAgent.entitlements` 지정
6. Signing & Capabilities에서 App Sandbox 비활성화
7. ⌘R 실행

## 권한

### Screen Recording (필수)
- 앱 실행 시 macOS가 자동으로 권한 요청 다이얼로그 표시
- System Settings → Privacy & Security → Screen Recording에서 허용
- **권한 없이도 앱은 크래시 없이 동작** (안내 메시지만 표시)

### Accessibility (선택)
- UI 트리에서 텍스트 추출을 위해 필요
- 없어도 기본 기능(화면 캡처 + 앱/윈도우 메타데이터)은 정상 동작
- System Settings → Privacy & Security → Accessibility에서 허용

## 데이터 파이프라인

```
ScreenCaptureKit (1-2fps, 1/4 해상도)
        ↓
  FrameDiffEngine (픽셀 변화량 계산)
        ↓
  EventDetectionService
  ├─ 앱 전환 감지 → 즉시 이벤트 생성
  ├─ 큰 변화 감지 → 이벤트 업데이트
  ├─ 변화 없음 30초 → 이벤트 마감 (coalesce)
  └─ 민감화면 감지 → 차단, 메타만 기록
        ↓
  SQLite (~/Library/Application Support/ScreenAgent/screenagent.db)
```

## 프라이버시

- 원본 전체 화면 이미지: **저장하지 않음** (기본값)
- 저해상도 썸네일: 설정에서 ON 시에만 저장 (기본 OFF)
- 비밀번호/OTP/카드번호/메신저 화면: 자동 감지 → 차단
- LLM 연동: 사용자가 직접 API 키를 입력한 경우에만 동작
- 민감 이벤트는 LLM에 전송하지 않음

## SQLite 스키마

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

## 트러블슈팅

| 문제 | 해결 |
|------|------|
| "Screen Recording permission required" | System Settings → Privacy & Security → Screen Recording → ScreenAgent 허용 |
| 앱이 메뉴바에만 보임 | Dock 아이콘 클릭 또는 메뉴바 아이콘 → 메인 윈도우 열기 |
| 빌드 에러: signing | Build Settings에서 Code Sign Identity를 `-` 또는 `Sign to Run Locally`로 변경 |
| Sandbox 관련 에러 | Entitlements에서 `com.apple.security.app-sandbox`가 `false`인지 확인 |
| XcodeGen not found | `brew install xcodegen` 실행 |
| 이벤트가 저장되지 않음 | Dashboard에서 캡처 토글이 ON인지, Screen Recording 권한이 있는지 확인 |
