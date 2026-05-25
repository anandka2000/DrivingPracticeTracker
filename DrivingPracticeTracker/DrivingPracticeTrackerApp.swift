import SwiftUI

@main
struct SteerStartApp: App {
    @StateObject private var store = SessionStore.shared

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
    }
}
