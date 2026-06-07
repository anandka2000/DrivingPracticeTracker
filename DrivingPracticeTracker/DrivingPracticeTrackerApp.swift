import SwiftUI

@main
struct SteerStartApp: App {
    @StateObject private var store = SessionStore.shared

    init() {
        // Start monitoring as early as possible so detection works from background relaunches
        // (e.g. significant-location-change wakes the app from terminated state).
        if UserDefaults.standard.bool(forKey: "autoLoggingEnabled") {
            AutoDriveManager.shared.startMonitoring()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
