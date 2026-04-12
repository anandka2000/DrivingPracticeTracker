import SwiftUI

@main
struct DrivingPracticeTrackerApp: App {
    @StateObject private var store = SessionStore.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
