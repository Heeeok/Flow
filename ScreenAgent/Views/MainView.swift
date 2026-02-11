import SwiftUI

/// Root view with tab navigation
struct MainView: View {
    @ObservedObject var appState: AppState
    @State private var selectedTab: Tab = .dashboard

    enum Tab: String, CaseIterable {
        case dashboard = "Dashboard"
        case search = "Search"
        case settings = "Settings"

        var icon: String {
            switch self {
            case .dashboard: return "gauge.medium"
            case .search: return "magnifyingglass"
            case .settings: return "gear"
            }
        }
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 160, ideal: 180, max: 220)
        } detail: {
            detailView
        }
        .frame(minWidth: 700, minHeight: 480)
        .onAppear {
            Task {
                await appState.captureService.checkPermission()
                appState.eventDetection.refreshTodayCount()
            }
        }
    }

    private var sidebar: some View {
        List(Tab.allCases, id: \.rawValue, selection: $selectedTab) { tab in
            Label(tab.rawValue, systemImage: tab.icon)
                .tag(tab)
        }
        .listStyle(.sidebar)
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedTab {
        case .dashboard:
            DashboardView(appState: appState)
        case .search:
            SearchView(appState: appState)
        case .settings:
            SettingsView(appState: appState)
        }
    }
}
