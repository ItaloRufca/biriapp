import SwiftUI

struct GameDetailView: View {
    @EnvironmentObject private var session: AppSession

    let game: Game

    @State private var detail: GameDetail?
    @State private var isLoading = true
    @State private var isSavingRating = false
    @State private var isShowingRatingOptions = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            if let detail {
                VStack(alignment: .leading, spacing: 16) {
                    cover(detail)
                    titleSection(detail)
                    actionRow
                    statsRow(detail)
                    aboutSection(detail)
                }
                .padding(16)
            } else if isLoading {
                ProgressView("Carregando detalhes...")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 40)
            } else {
                Text(errorMessage ?? "Erro ao carregar detalhes")
                    .foregroundStyle(.red)
                    .padding(16)
            }
        }
        .background(Color(.systemGray6))
        .navigationTitle(game.name)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadDetail()
        }
        .confirmationDialog("Avaliar jogo", isPresented: $isShowingRatingOptions, titleVisibility: .visible) {
            ForEach(EmojiRating.options, id: \.value) { option in
                Button(option.emoji) {
                    Task { await setRating(option.value) }
                }
            }

            if session.ratingsByGameID[game.id] != nil {
                Button("Remover avaliação", role: .destructive) {
                    Task { await setRating(nil) }
                }
            }

            Button("Cancelar", role: .cancel) {}
        }
    }

    private func cover(_ detail: GameDetail) -> some View {
        HStack {
            Spacer()
            AsyncImage(url: detail.imageURL) { image in
                image
                    .resizable()
                    .scaledToFit()
            } placeholder: {
                Rectangle()
                    .fill(Color(.systemGray5))
            }
            .frame(width: 230, height: 300)
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func titleSection(_ detail: GameDetail) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(detail.name)
                .font(.system(size: 46, weight: .bold))
                .foregroundStyle(Color(.label))

            Text("(\(yearText(detail)))")
                .font(.title2.weight(.medium))
                .foregroundStyle(Color(.secondaryLabel))
        }
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            Button {
                Task { await toggleCollection() }
            } label: {
                Label(
                    session.collectionGameIDs.contains(game.id) ? "Na coleção" : "Coleção",
                    systemImage: session.collectionGameIDs.contains(game.id) ? "checkmark" : "plus"
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .font(.headline)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(.systemGray5))
            .foregroundStyle(Color(.secondaryLabel))

            Button {
                Task { await toggleWishlist() }
            } label: {
                Label(
                    session.wishlistGameIDs.contains(game.id) ? "Em desejos" : "Desejos",
                    systemImage: "heart"
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .font(.headline)
            }
            .buttonStyle(.bordered)
            .tint(.pink)
        }
    }

    private func statsRow(_ detail: GameDetail) -> some View {
        HStack {
            statItem(icon: "person.2", title: "Jogadores", value: playersText(detail))
            Divider()
            statItem(icon: "timer", title: "Tempo", value: playingTimeText(detail))
            Divider()
            statItem(icon: "trophy", title: "Rank", value: "#\(game.rank)")
        }
        .padding(14)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func statItem(icon: String, title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.pink)
            Text(title)
                .font(.subheadline)
                .foregroundStyle(Color(.secondaryLabel))
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(Color(.label))
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func aboutSection(_ detail: GameDetail) -> some View {
        let text = preferredAboutText(detail)
        if !text.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Sobre o Jogo")
                        .font(.title2.weight(.bold))
                    Spacer()
                    Button {
                        isShowingRatingOptions = true
                    } label: {
                        Text("Avaliar: \(EmojiRating.label(for: session.ratingsByGameID[game.id]))")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .disabled(isSavingRating)
                }

                Text(text)
                    .font(.body)
                    .foregroundStyle(Color(.secondaryLabel))
                    .lineSpacing(3)
            }
        }
    }

    private func preferredAboutText(_ detail: GameDetail) -> String {
        let summary = (detail.summary ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !summary.isEmpty {
            return summary
        }
        return (detail.description ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func yearText(_ detail: GameDetail) -> String {
        if let subtitle = detail.subtitle {
            let year = subtitle.filter { $0.isNumber }
            if year.count >= 4 {
                return String(year.prefix(4))
            }
        }
        if let year = detail.yearPublished {
            return String(year)
        }
        return "-"
    }

    private func playersText(_ detail: GameDetail) -> String {
        switch (detail.minPlayers, detail.maxPlayers) {
        case let (min?, max?) where min == max:
            return "\(min)"
        case let (min?, max?):
            return "\(min) - \(max)"
        default:
            return "-"
        }
    }

    private func playingTimeText(_ detail: GameDetail) -> String {
        guard let minutes = detail.playingTime, minutes > 0 else { return "? min" }
        return "\(minutes) min"
    }

    private func loadDetail() async {
        isLoading = true
        errorMessage = nil
        do {
            detail = try await session.fetchGameDetail(gameID: game.id)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    private func toggleCollection() async {
        do {
            let on = !session.collectionGameIDs.contains(game.id)
            try await session.setCollection(on, for: game)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func toggleWishlist() async {
        do {
            let on = !session.wishlistGameIDs.contains(game.id)
            try await session.setWishlist(on, for: game)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func setRating(_ rating: Int?) async {
        isSavingRating = true
        do {
            try await session.setRating(rating, for: game)
        } catch {
            errorMessage = error.localizedDescription
        }
        isSavingRating = false
    }
}

#Preview {
    NavigationStack {
        GameDetailView(
            game: Game(
                id: "preview",
                name: "Speakeasy",
                rank: 2283,
                imageURL: nil,
                category: "Categoria",
                playersRange: "1-4",
                communityRating: 4.2,
                ratingCount: 100,
                userRating: 4
            )
        )
        .environmentObject(AppSession())
    }
}
