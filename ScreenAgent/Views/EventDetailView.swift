import SwiftUI

/// Detail view for a selected event
struct EventDetailView: View {
    let event: ScreenEvent

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {

                // Header
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "app.fill")
                            .foregroundColor(.blue)
                        Text(event.appName)
                            .font(.system(size: 16, weight: .semibold))
                    }

                    Text(event.windowTitle)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                        .textSelection(.enabled)
                }

                Divider()

                // Time info
                VStack(alignment: .leading, spacing: 6) {
                    Label("Time", systemImage: "clock")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)

                    HStack(spacing: 16) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Start")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text(formatDate(event.timestampStart))
                                .font(.system(size: 12, design: .monospaced))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("End")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text(formatDate(event.timestampEnd))
                                .font(.system(size: 12, design: .monospaced))
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Duration")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                            Text(event.durationFormatted)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                        }
                    }
                }

                Divider()

                // Summary
                VStack(alignment: .leading, spacing: 6) {
                    Label("Summary", systemImage: "text.alignleft")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)

                    Text(event.summary)
                        .font(.system(size: 13))
                        .textSelection(.enabled)
                }

                // Tags
                if !event.tags.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Tags", systemImage: "tag")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)

                        FlowLayout(spacing: 4) {
                            ForEach(event.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.system(size: 11))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.blue.opacity(0.1))
                                    .foregroundColor(.blue)
                                    .cornerRadius(4)
                            }
                        }
                    }
                }

                // Sensitivity
                if event.sensitivityFlag != .none {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(.orange)
                        Text("Sensitivity: \(sensitivityLabel)")
                            .font(.system(size: 12))
                            .foregroundColor(.orange)
                    }
                    .padding(8)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(6)
                }

                // Thumbnail
                if let thumbPath = event.thumbnailPath,
                   let image = NSImage(contentsOfFile: thumbPath) {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Thumbnail", systemImage: "photo")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)

                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 200)
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    }
                }

                // AX Text
                if let axText = event.axTextSnippet, !axText.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Extracted Text", systemImage: "text.viewfinder")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)

                        Text(axText)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                            .textSelection(.enabled)
                            .padding(8)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(6)
                    }
                }

                // Metadata
                VStack(alignment: .leading, spacing: 4) {
                    Label("Metadata", systemImage: "info.circle")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)

                    Group {
                        metadataRow("Bundle ID", value: event.appBundleID)
                        metadataRow("Event ID", value: event.id)
                    }
                }

                Spacer()
            }
            .padding(16)
        }
    }

    private var sensitivityLabel: String {
        switch event.sensitivityFlag {
        case .none: return "None"
        case .low: return "Low"
        case .high: return "High"
        case .blocked: return "Blocked"
        }
    }

    private func formatDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f.string(from: date)
    }

    private func metadataRow(_ label: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(label + ":")
                .font(.system(size: 10))
                .foregroundColor(.secondary)
                .frame(width: 70, alignment: .trailing)
            Text(value)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
                .textSelection(.enabled)
        }
    }
}

// Simple flow layout for tags
struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            totalHeight = y + rowHeight
        }

        return (CGSize(width: maxWidth, height: totalHeight), positions)
    }
}
