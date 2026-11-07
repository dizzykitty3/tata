import SwiftUI

@main
struct TATAApp: App {
    init() {
        QuickInfoDatePreferences.initializeFromSystem()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
