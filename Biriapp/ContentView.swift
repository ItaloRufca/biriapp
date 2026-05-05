import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var session: AppSession

    var body: some View {
        Group {
            if session.isAuthenticated {
                MainTabView()
            } else {
                LoginView()
            }
        }
        .animation(.easeInOut(duration: 0.2), value: session.isAuthenticated)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppSession())
}
