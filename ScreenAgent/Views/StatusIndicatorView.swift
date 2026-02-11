import SwiftUI

/// LED-style status indicator that shows capture state
struct StatusIndicatorView: View {
    let isActive: Bool
    var size: CGFloat = 12

    var body: some View {
        Circle()
            .fill(isActive ? Color.green : Color.gray.opacity(0.4))
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .fill(isActive ? Color.green.opacity(0.5) : Color.clear)
                    .frame(width: size + 4, height: size + 4)
                    .blur(radius: 3)
            )
            .overlay(
                Circle()
                    .stroke(isActive ? Color.green.opacity(0.6) : Color.gray.opacity(0.3), lineWidth: 1)
            )
            .animation(.easeInOut(duration: 0.3), value: isActive)
    }
}

/// Permission status badge
struct PermissionBadge: View {
    let granted: Bool
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundColor(granted ? .green : .red)
                .font(.system(size: 14))
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
    }
}
