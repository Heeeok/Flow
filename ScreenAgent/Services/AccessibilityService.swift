import Foundation
import AppKit

/// Extracts UI text and element information using macOS Accessibility (AX) API.
/// Operates defensively — only works when permission is granted and the target app supports AX.
final class AccessibilityService {

    static let shared = AccessibilityService()

    // MARK: - Permission

    var hasPermission: Bool {
        AXIsProcessTrusted()
    }

    func requestPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Text Extraction

    /// Extract visible text from the focused window of the frontmost app.
    /// Returns nil if AX is not available or the app doesn't support it.
    func extractFocusedWindowText(maxLength: Int = 2000) -> String? {
        guard hasPermission else { return nil }

        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return nil }
        let pid = frontApp.processIdentifier

        let axApp = AXUIElementCreateApplication(pid)

        // Get focused window
        var focusedWindowValue: AnyObject?
        let result = AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &focusedWindowValue)
        guard result == .success, let focusedWindow = focusedWindowValue else {
            return nil
        }

        // Recursively collect text from the window's UI tree
        var texts: [String] = []
        collectTexts(from: focusedWindow as! AXUIElement, into: &texts, depth: 0, maxDepth: 10)

        let combined = texts.joined(separator: " ")
        if combined.count > maxLength {
            return String(combined.prefix(maxLength))
        }
        return combined.isEmpty ? nil : combined
    }

    /// Get the focused element's value (e.g., text field content)
    func getFocusedElementText() -> String? {
        guard hasPermission else { return nil }

        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return nil }
        let pid = frontApp.processIdentifier

        let axApp = AXUIElementCreateApplication(pid)

        var focusedElement: AnyObject?
        let result = AXUIElementCopyAttributeValue(axApp, kAXFocusedUIElementAttribute as CFString, &focusedElement)
        guard result == .success, let element = focusedElement else {
            return nil
        }

        return getStringAttribute(element as! AXUIElement, attribute: kAXValueAttribute)
    }

    // MARK: - Recursive Text Collection

    private func collectTexts(from element: AXUIElement, into texts: inout [String], depth: Int, maxDepth: Int) {
        guard depth < maxDepth else { return }
        guard texts.count < 100 else { return } // Safety limit

        // Try to get text attributes
        if let title = getStringAttribute(element, attribute: kAXTitleAttribute), !title.isEmpty {
            texts.append(title)
        }
        if let value = getStringAttribute(element, attribute: kAXValueAttribute), !value.isEmpty {
            // Avoid very long values (e.g., entire document content)
            if value.count < 500 {
                texts.append(value)
            }
        }
        if let desc = getStringAttribute(element, attribute: kAXDescriptionAttribute), !desc.isEmpty {
            texts.append(desc)
        }

        // Get children and recurse
        var childrenValue: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenValue)
        guard result == .success, let children = childrenValue as? [AXUIElement] else { return }

        for child in children {
            collectTexts(from: child, into: &texts, depth: depth + 1, maxDepth: maxDepth)
        }
    }

    private func getStringAttribute(_ element: AXUIElement, attribute: String) -> String? {
        var value: AnyObject?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success, let str = value as? String else { return nil }
        return str
    }

    // MARK: - Window Info

    struct WindowInfo {
        let title: String
        let role: String
        let subrole: String
    }

    func getFocusedWindowInfo() -> WindowInfo? {
        guard hasPermission else { return nil }
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return nil }
        let pid = frontApp.processIdentifier

        let axApp = AXUIElementCreateApplication(pid)

        var windowValue: AnyObject?
        let result = AXUIElementCopyAttributeValue(axApp, kAXFocusedWindowAttribute as CFString, &windowValue)
        guard result == .success, let window = windowValue else { return nil }

        let axWindow = window as! AXUIElement
        let title = getStringAttribute(axWindow, attribute: kAXTitleAttribute) ?? ""
        let role = getStringAttribute(axWindow, attribute: kAXRoleAttribute) ?? ""
        let subrole = getStringAttribute(axWindow, attribute: kAXSubroleAttribute) ?? ""

        return WindowInfo(title: title, role: role, subrole: subrole)
    }
}
