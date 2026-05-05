import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var session: AppSession
    @State private var isShowingProfile = false

    var body: some View {
        TabView {
            HomeView()
                .tabItem { Label("Início", systemImage: "house.fill") }

            RankingView()
                .tabItem { Label("Ranking", systemImage: "list.number") }

            CollectionView()
                .tabItem { Label("Coleção", systemImage: "square.grid.2x2.fill") }
        }
        .tint(AppTheme.accent)
        .overlay(alignment: .topTrailing) {
            Button {
                isShowingProfile = true
            } label: {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 30, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(AppTheme.accent)
                    .clipShape(Circle())
                    .shadow(color: .black.opacity(0.24), radius: 14, x: 0, y: 10)
                    .padding(.top, 8)
                    .padding(.trailing, 12)
            }
        }
        .sheet(isPresented: $isShowingProfile) {
            ProfileView()
                .environmentObject(session)
        }
    }
}

#Preview {
    MainTabView()
        .environmentObject(AppSession())
}
