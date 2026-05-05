import SwiftUI

struct RankingView: View {
    @EnvironmentObject private var session: AppSession

    @State private var selectedTab: RankingTab = .games
    @State private var searchText = ""
    @State private var searchResults: [Game] = []
    @State private var isSearching = false
    @State private var isLoadingAction = false
    @State private var errorMessage: String?

    private var isSearchMode: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var displayedGames: [Game] {
        isSearchMode ? searchResults : session.rankedGames
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                header

                if selectedTab == .games {
                    searchBar

                    if isSearching {
                        ProgressView("Buscando...")
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    List(displayedGames) { game in
                        NavigationLink {
                            GameDetailView(game: game)
                        } label: {
                            gameRow(game)
                        }
                        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                } else {
                    List(Array(session.topReviewers.enumerated()), id: \.element.id) { index, reviewer in
                        reviewerRow(index: index + 1, reviewer: reviewer)
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
            .navigationTitle("Ranking")
            .refreshable {
                await reloadData()
            }
            .task(id: searchText) {
                await runSearchIfNeeded()
            }
        }
    }

    private var header: some View {
        Picker("Ranking", selection: $selectedTab) {
            Text("Jogos").tag(RankingTab.games)
            Text("Avaliadores").tag(RankingTab.reviewers)
        }
        .pickerStyle(.segmented)
        .padding(12)
        .premiumPanel()
        .padding(.top, 8)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Buscar jogo", text: $searchText)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .premiumPanel()
    }

    private func gameRow(_ game: Game) -> some View {
        HStack(spacing: 12) {
            Text(isSearchMode ? "" : "#\(game.rank)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppTheme.subInk)
                .frame(width: 34)

            AsyncImage(url: game.imageURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Rectangle().fill(AppTheme.accentSoft)
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(game.name)
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)
                    .lineLimit(1)

                Text("\(game.playersRange) • \(game.category)")
                    .font(.caption)
                    .foregroundStyle(AppTheme.subInk)

                if let rating = game.userRating {
                    Text("Sua nota: \(EmojiRating.label(for: rating))")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(AppTheme.accent)
                }
            }

            Spacer()

            if !isSearchMode {
                Text(String(format: "%.1f", game.communityRating))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppTheme.ink)
            }

            Menu {
                Button(session.collectionGameIDs.contains(game.id) ? "Remover da coleção" : "Adicionar à coleção") {
                    Task { await toggleCollection(game) }
                }

                Button(session.wishlistGameIDs.contains(game.id) ? "Remover dos desejos" : "Adicionar aos desejos") {
                    Task { await toggleWishlist(game) }
                }

                Button(session.favoriteGameIDs.contains(game.id) ? "Remover dos favoritos" : "Adicionar aos favoritos") {
                    Task { await toggleFavorite(game) }
                }

                Divider()

                ForEach(EmojiRating.options, id: \.value) { option in
                    Button("Avaliar: \(option.emoji)") {
                        Task { await setRating(option.value, for: game) }
                    }
                }

                Button("Remover avaliação", role: .destructive) {
                    Task { await setRating(nil, for: game) }
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .disabled(isLoadingAction)
        }
        .padding(12)
        .premiumCard()
    }

    private func reviewerRow(index: Int, reviewer: Reviewer) -> some View {
        HStack(spacing: 12) {
            Text("#\(index)")
                .font(.caption.weight(.bold))
                .foregroundStyle(AppTheme.subInk)
                .frame(width: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(reviewer.username)
                    .font(.headline)
                    .foregroundStyle(AppTheme.ink)
                Text("\(reviewer.ratingCount) avaliações")
                    .font(.caption)
                    .foregroundStyle(AppTheme.subInk)
            }

            Spacer()
        }
        .padding(12)
        .premiumCard()
    }

    private func runSearchIfNeeded() async {
        guard selectedTab == .games else { return }
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            searchResults = []
            return
        }

        isSearching = true
        errorMessage = nil

        do {
            try await Task.sleep(for: .milliseconds(300))
            if trimmed == searchText.trimmingCharacters(in: .whitespacesAndNewlines) {
                searchResults = try await session.searchCatalogGames(query: trimmed)
            }
        } catch {
            errorMessage = error.localizedDescription
        }

        isSearching = false
    }

    private func toggleCollection(_ game: Game) async {
        isLoadingAction = true
        do {
            try await session.setCollection(!session.collectionGameIDs.contains(game.id), for: game)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingAction = false
    }

    private func toggleWishlist(_ game: Game) async {
        isLoadingAction = true
        do {
            try await session.setWishlist(!session.wishlistGameIDs.contains(game.id), for: game)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingAction = false
    }

    private func toggleFavorite(_ game: Game) async {
        isLoadingAction = true
        do {
            try await session.setFavorite(!session.favoriteGameIDs.contains(game.id), for: game)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingAction = false
    }

    private func setRating(_ rating: Int?, for game: Game) async {
        isLoadingAction = true
        do {
            try await session.setRating(rating, for: game)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoadingAction = false
    }

    private func reloadData() async {
        do {
            try await session.reloadData()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private enum RankingTab: String, CaseIterable {
    case games
    case reviewers
}

#Preview {
    RankingView()
        .environmentObject(AppSession())
}
