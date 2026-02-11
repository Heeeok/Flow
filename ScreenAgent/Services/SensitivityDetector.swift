import Foundation

/// Detects potentially sensitive screen content using heuristics
/// on app bundle IDs, window titles, and optionally OCR/AX text.
struct SensitivityDetector {

    // Apps that always contain sensitive content
    private let blockedAppBundles: Set<String> = [
        "com.apple.keychainaccess",
        "com.lastpass.LastPass",
        "com.agilebits.onepassword7",
        "com.agilebits.onepassword-osx",
        "com.bitwarden.desktop",
        "com.dashlane.Dashlane",
    ]

    // Apps with personal messaging (high sensitivity by default)
    private let messagingAppBundles: Set<String> = [
        "com.apple.MobileSMS",       // Messages
        "com.facebook.archon",       // Messenger
        "com.tinyspeck.slackmacgap", // Slack
        "com.hnc.Discord",           // Discord
        "ru.keepcoder.Telegram",     // Telegram
        "net.whatsapp.WhatsApp",     // WhatsApp
        "com.kakao.KakaoTalkMac",    // KakaoTalk
        "jp.naver.line.mac",         // LINE
    ]

    // Window title patterns that suggest sensitive content
    private let sensitiveWindowPatterns: [String] = [
        "password", "비밀번호", "암호",
        "sign in", "log in", "login", "로그인",
        "credit card", "신용카드", "카드번호",
        "bank", "banking", "은행",
        "account number", "계좌",
        "social security", "주민등록",
        "one-time", "otp", "인증번호", "인증코드",
        "two-factor", "2fa",
        "private browsing", "incognito", "시크릿",
        "keychain",
    ]

    // Text content patterns for OCR/AX text analysis
    private let sensitiveTextPatterns: [NSRegularExpression] = {
        let patterns = [
            "\\b\\d{4}[- ]?\\d{4}[- ]?\\d{4}[- ]?\\d{4}\\b",  // Credit card
            "\\b\\d{3}-\\d{2}-\\d{4}\\b",                        // SSN
            "\\b\\d{6}-\\d{7}\\b",                                // Korean ID
            "\\b\\d{3,4}-\\d{4}-\\d{4}\\b",                      // Korean bank account
            "password\\s*[:=]\\s*\\S+",                            // Password field
            "\\botp\\s*[:=]?\\s*\\d{4,8}\\b",                     // OTP code
        ]
        return patterns.compactMap { try? NSRegularExpression(pattern: $0, options: .caseInsensitive) }
    }()

    // MARK: - Assessment

    /// Assess sensitivity based on app metadata only (fast, no OCR needed)
    func assessFromMetadata(appBundle: String, windowTitle: String) -> ScreenEvent.SensitivityLevel {
        // Blocked apps
        if blockedAppBundles.contains(appBundle) {
            return .blocked
        }

        // Messaging apps — high sensitivity (store metadata only, no content)
        if messagingAppBundles.contains(appBundle) {
            return .high
        }

        // Check window title patterns
        let titleLower = windowTitle.lowercased()
        for pattern in sensitiveWindowPatterns {
            if titleLower.contains(pattern) {
                // Password/OTP/card patterns → blocked
                if pattern.contains("password") || pattern.contains("비밀번호") ||
                   pattern.contains("otp") || pattern.contains("인증") ||
                   pattern.contains("credit") || pattern.contains("카드번호") ||
                   pattern.contains("incognito") || pattern.contains("시크릿") ||
                   pattern.contains("private browsing") {
                    return .blocked
                }
                return .high
            }
        }

        return .none
    }

    /// Assess sensitivity including text content analysis (for OCR/AX text)
    func assessWithText(appBundle: String, windowTitle: String, textContent: String?) -> ScreenEvent.SensitivityLevel {
        // Start with metadata assessment
        let metaLevel = assessFromMetadata(appBundle: appBundle, windowTitle: windowTitle)
        guard metaLevel == .none else { return metaLevel }

        // Check text content if available
        guard let text = textContent, !text.isEmpty else { return .none }

        let range = NSRange(text.startIndex..., in: text)
        for regex in sensitiveTextPatterns {
            if regex.firstMatch(in: text, options: [], range: range) != nil {
                return .high
            }
        }

        return .none
    }

    /// Mask sensitive portions of text (for storage)
    func maskSensitiveText(_ text: String) -> String {
        var masked = text
        let range = NSRange(text.startIndex..., in: text)

        for regex in sensitiveTextPatterns {
            masked = regex.stringByReplacingMatches(in: masked, options: [], range: range, withTemplate: "[MASKED]")
        }

        return masked
    }
}
