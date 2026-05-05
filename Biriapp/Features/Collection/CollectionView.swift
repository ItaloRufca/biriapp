import SwiftUI

struct CollectionView: View {
    @EnvironmentObject private var session: AppSession

    @State private var selectedTab: CollectionTab = .collection
    @State private var errorMessage: String?

    private var games: [Game] {
        switch selectedTab {
        case .collection: return session.collectionGames
        case .wishlist: return session.wishlistGames
        case .favorites: return session.favoriteGames
        case .ratings: return session.ratedGames
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Picker("Coleção", selection: $selectedTab) {
                    Text("Coleção").tag(CollectionTab.collection)
                    Text("Desejos").tag(CollectionTab.wishlist)
                    Text("Favoritos").tag(CollectionTab.favorites)
                    Text("Notas").tag(CollectionTab.ratings)
                }
                .pickerStyle(.segmented)
                .padding(12)
                .premiumPanel()

                if games.isEmpty {
                    ContentUnavailableView("Nenhum jogo encontrado", systemImage: "square.grid.2x2")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(games) { game in
                        NavigationLink {
                            GameDetailView(game: game)
                        } label: {
                            row(game)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            actionButtons(for: game)
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 16)
            .premiumBackground()
            .navigationTitle("Coleção")
            .refreshable {
                await reloadData()
            }
        }
    }

    private func row(_ game: Game) -> some View {
        HStack(spacing: 12) {
            AsyncImage(url: game.imageURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Rectangle().fill(AppTheme.accentSoft)
            }
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(game.name)
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)

                Text("\(game.playersRange) • \(game.category)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.subInk)

                if let rating = game.userRating, selectedTab == .ratings {
                    Text("Sua nota: \(EmojiRating.label(for: rating))")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
        .padding(12)
        .premiumCard()
    }

    @ViewBuilder
    private func actionButtons(for game: Game) -> some View {
        if selectedTab == .collection {
            Button("Remover") { Task { await setCollection(false, for: game) } }.tint(.red)
        }
        if selectedTab == .wishlist {
            Button("Remover") { Task { await setWishlist(false, for: game) } }.tint(.red)
        }
        if selectedTab == .favorites {
            Button("Remover") { Task { await setFavorite(false, for: game) } }.tint(.red)
        }
        if selectedTab == .ratings {
            Button("Limpar nota") { Task { await setRating(nil, for: game) } }.tint(.orange)
        }

        Button(session.collectionGameIDs.contains(game.id) ? "Coleção ✓" : "Coleção") {
            Task { await setCollection(!session.collectionGameIDs.contains(game.id), for: game) }
        }
        .tint(.blue)

        Button(session.wishlistGameIDs.contains(game.id) ? "Desejo ✓" : "Desejo") {
            Task { await setWishlist(!session.wishlistGameIDs.contains(game.id), for: game) }
        }
        .tint(.pink)

        Button(session.favoriteGameIDs.contains(game.id) ? "Favorito ✓" : "Favorito") {
            Task { await setFavorite(!session.favoriteGameIDs.contains(game.id), for: game) }
        }
        .tint(.yellow)
    }

    private func setCollection(_ isOn: Bool, for game: Game) async {
        do { try await session.setCollection(isOn, for: game) }
        catch { errorMessage = error.localizedDescription }
    }

    private func setWishlist(_ isOn: Bool, for game: Game) async {
        do { try await session.setWishlist(isOn, for: game) }
        catch { errorMessage = error.localizedDescription }
    }

    private func setFavorite(_ isOn: Bool, for game: Game) async {
        do { try await session.setFavorite(isOn, for: game) }
        catch { errorMessage = error.localizedDescription }
    }

    private func setRating(_ rating: Int?, for game: Game) async {
        do { try await session.setRating(rating, for: game) }
        catch { errorMessage = error.localizedDescription }
    }

    private func reloadData() async {
        do { try await session.reloadData() }
        catch { errorMessage = error.localizedDescription }
    }
}

private enum CollectionTab: String, CaseIterable {
    case collection
    case wishlist
    case favorites
    case ratings
}

#Preview {
    CollectionView()
        .environmentObject(AppSession())
}
