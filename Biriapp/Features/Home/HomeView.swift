import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var session: AppSession

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    greeting
                    statsRow

                    Text("Top do momento")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(AppTheme.ink)

                    ForEach(session.rankedGames.prefix(10)) { game in
                        NavigationLink {
                            GameDetailView(game: game)
                        } label: {
                            gameRow(game)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
            }
            .premiumBackground()
            .navigationTitle("BiriApp")
        }
    }

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Olá, \(session.username)")
                .font(.title.weight(.bold))
                .foregroundStyle(AppTheme.ink)

            Text("Organize sua coleção, desejos e avaliações de carteados.")
                .font(.subheadline)
                .foregroundStyle(AppTheme.subInk)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .premiumCard()
    }

    private var statsRow: some View {
        HStack(spacing: 8) {
            statChip("Coleção", value: session.collectionGames.count)
            statChip("Desejos", value: session.wishlistGames.count)
            statChip("Favoritos", value: session.favoriteGames.count)
            statChip("Notas", value: session.ratedGames.count)
        }
    }

    private func statChip(_ title: String, value: Int) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.headline.weight(.bold))
                .foregroundStyle(AppTheme.ink)
            Text(title)
                .font(.caption2)
                .foregroundStyle(AppTheme.subInk)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .premiumPanel()
    }

    private func gameRow(_ game: Game) -> some View {
        HStack(spacing: 12) {
            Text("#\(game.rank)")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.subInk)
                .frame(width: 28)

            AsyncImage(url: game.imageURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Rectangle().fill(AppTheme.accentSoft)
            }
            .frame(width: 56, height: 56)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(game.name)
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)

                Text("\(game.playersRange) • \(game.category)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.subInk)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(String(format: "%.1f", game.communityRating))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.ink)
                Text("\(game.ratingCount)")
                    .font(.caption2)
                    .foregroundStyle(AppTheme.subInk)
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .premiumCard()
    }
}

#Preview {
    HomeView()
        .environmentObject(AppSession())
}
