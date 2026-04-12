import SwiftUI

struct ContentView: View {
    @EnvironmentObject var store: SessionStore

    var body: some View {
        TabView {
            DashboardView()
                .tabItem {
                    Label("Dashboard", systemImage: "chart.bar.fill")
                }

            LogSessionView()
                .tabItem {
                    Label("Log Drive", systemImage: "plus.circle.fill")
                }

            SessionListView()
                .tabItem {
                    Label("History", systemImage: "list.bullet.rectangle.portrait.fill")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
    }
}
