import SwiftUI

@main
struct BiriappApp: App {
    @StateObject private var session = AppSession()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(session)
        }
    }
}
