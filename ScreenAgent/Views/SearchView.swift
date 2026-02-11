import SwiftUI

/// Event search and browsing view
struct SearchView: View {
    @ObservedObject var appState: AppState
    @State private var keyword: String = ""
    @State private var dateFrom: Date = Calendar.current.startOfDay(for: Date())
    @State private var dateTo: Date = Date()
    @State private var useDateFilter: Bool = false
    @State private var results: [ScreenEvent] = []
    @State private var selectedEvent: ScreenEvent?

    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Search Bar
            searchBar

            Divider()

            // MARK: - Results
            if results.isEmpty {
                emptyState
            } else {
                HSplitView {
                    resultsList
                        .frame(minWidth: 280)

                    if let event = selectedEvent {
                        EventDetailView(event: event)
                            .frame(minWidth: 260)
                    }
                }
            }
        }
        .onAppear {
            performSearch()
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search events...", text: $keyword)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .onSubmit { performSearch() }

                if !keyword.isEmpty {
                    Button(action: {
                        keyword = ""
                        performSearch()
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.plain)
                }

                Button("Search") { performSearch() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }

            HStack(spacing: 12) {
                Toggle("Date filter", isOn: $useDateFilter)
                    .font(.system(size: 11))
                    .toggleStyle(.checkbox)
                    .onChange(of: useDateFilter) { _ in performSearch() }

                if useDateFilter {
                    DatePicker("From:", selection: $dateFrom, displayedComponents: [.date])
                        .font(.system(size: 11))
                        .labelsHidden()
                        .onChange(of: dateFrom) { _ in performSearch() }

                    Text("—")
                        .foregroundColor(.secondary)

                    DatePicker("To:", selection: $dateTo, displayedComponents: [.date])
                        .font(.system(size: 11))
                        .labelsHidden()
                        .onChange(of: dateTo) { _ in performSearch() }
                }

                Spacer()

                Text("\(results.count) events")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(12)
    }

    // MARK: - Results List

    private var resultsList: some View {
        List(results, selection: $selectedEvent) { event in
            EventRowView(event: event, isSelected: selectedEvent?.id == event.id)
                .tag(event)
                .onTapGesture {
                    selectedEvent = event
                }
        }
        .listStyle(.inset)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.5))
            Text("No events found")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
            if !keyword.isEmpty {
                Text("Try a different search term")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary.opacity(0.7))
            } else {
                Text("Start capturing to see events here")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary.opacity(0.7))
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Search Logic

    private func performSearch() {
        results = DatabaseService.shared.searchEvents(
            keyword: keyword,
            dateFrom: useDateFilter ? dateFrom : nil,
            dateTo: useDateFilter ? dateTo : nil,
            limit: 500
        )
    }
}

// MARK: - Event Row

struct EventRowView: View {
    let event: ScreenEvent
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(event.timeFormatted)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)

                Spacer()

                Text(event.durationFormatted)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(.secondary)

                if event.sensitivityFlag != .none {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)
                }
            }

            HStack(spacing: 6) {
                appIcon
                Text(event.appName)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)
            }

            Text(event.summary)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .lineLimit(2)

            if !event.tags.isEmpty {
                HStack(spacing: 4) {
                    ForEach(event.tags.prefix(4), id: \.self) { tag in
                        Text(tag)
                            .font(.system(size: 9))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(tagColor(tag).opacity(0.15))
                            .foregroundColor(tagColor(tag))
                            .cornerRadius(3)
                    }
                }
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private var appIcon: some View {
        Group {
            if let app = NSRunningApplication.runningApplications(withBundleIdentifier: event.appBundleID).first,
               let icon = app.icon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 16, height: 16)
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
    }

    private func tagColor(_ tag: String) -> Color {
        switch tag {
        case "coding": return .blue
        case "browsing": return .purple
        case "terminal": return .green
        case "email": return .orange
        case "communication": return .teal
        case "writing": return .indigo
        case "design": return .pink
        case "error": return .red
        case "sensitive": return .red
        case "search": return .cyan
        default: return .gray
        }
    }
}

// Make ScreenEvent hashable for List selection
extension ScreenEvent: Hashable {
    static func == (lhs: ScreenEvent, rhs: ScreenEvent) -> Bool {
        lhs.id == rhs.id
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}
