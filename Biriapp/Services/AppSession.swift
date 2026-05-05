import Foundation
import Combine
import Supabase

@MainActor
final class AppSession: ObservableObject {
    @Published var isAuthenticated = false
    @Published var email = ""
    @Published var username = "Jogador"
    @Published var avatarURLString = ""
    @Published var visibility: ProfileVisibility = .public
    @Published var hasClaimedLegacy = false

    @Published var catalogGames: [Game] = []
    @Published var rankedGames: [Game] = []
    @Published var topReviewers: [Reviewer] = []

    @Published var collectionGameIDs: Set<String> = []
    @Published var wishlistGameIDs: Set<String> = []
    @Published var favoriteGameIDs: Set<String> = []
    @Published var ratingsByGameID: [String: Int] = [:]
    private let bggService = BggService()

    private var allKnownGames: [Game] {
        var byID: [String: Game] = [:]
        for game in catalogGames { byID[game.id] = game }
        for game in rankedGames { byID[game.id] = game }

        return byID.values.map { game in
            var updated = game
            updated.userRating = ratingsByGameID[game.id]
            return updated
        }
    }
    
    private var knownGameByID: [String: Game] {
        Dictionary(uniqueKeysWithValues: allKnownGames.map { ($0.id, $0) })
    }
    
    private func hydratedGame(for gameID: String) -> Game {
        if var existing = knownGameByID[gameID] {
            existing.userRating = ratingsByGameID[gameID]
            return existing
        }
        
        return Game(
            id: gameID,
            name: "Jogo",
            rank: 0,
            imageURL: nil,
            category: "Carteado",
            playersRange: "-",
            communityRating: 0,
            ratingCount: 0,
            userRating: ratingsByGameID[gameID]
        )
    }

    var collectionGames: [Game] {
        collectionGameIDs
            .map(hydratedGame)
            .sorted { $0.name < $1.name }
    }

    var wishlistGames: [Game] {
        wishlistGameIDs
            .map(hydratedGame)
            .sorted { $0.name < $1.name }
    }

    var favoriteGames: [Game] {
        favoriteGameIDs
            .map(hydratedGame)
            .sorted { $0.name < $1.name }
    }

    var ratedGames: [Game] {
        ratingsByGameID.keys
            .map(hydratedGame)
            .sorted { ($0.userRating ?? 0) > ($1.userRating ?? 0) }
    }

    init() {
        Task {
            await bootstrap()
        }
    }

    func signIn(email: String, password: String) async throws {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanEmail.isEmpty, !cleanPassword.isEmpty else {
            throw SessionError.invalidCredentials
        }

        try await supabase.auth.signIn(email: cleanEmail, password: cleanPassword)
        guard let user = supabase.auth.currentUser else {
            throw SessionError.userNotFound
        }

        applyUser(user)
        try await refreshRemoteData(for: user)
        isAuthenticated = true
    }

    func signUp(email: String, password: String) async throws {
        let cleanEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleanEmail.isEmpty, !cleanPassword.isEmpty else {
            throw SessionError.invalidCredentials
        }

        _ = try await supabase.auth.signUp(email: cleanEmail, password: cleanPassword)
    }

    func signOut() async throws {
        try await supabase.auth.signOut()
        clearState()
    }

    func updateProfile(username: String, avatarURLString: String, visibility: ProfileVisibility) async throws {
        guard let user = supabase.auth.currentUser else {
            throw SessionError.userNotFound
        }

        let cleanName = username.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalName = cleanName.isEmpty ? "Jogador" : cleanName
        let cleanAvatar = avatarURLString.trimmingCharacters(in: .whitespacesAndNewlines)

        let payload = ProfileUpsert(
            id: user.id,
            username: finalName,
            avatarURL: cleanAvatar.isEmpty ? nil : cleanAvatar,
            visibility: visibility.rawValue
        )

        try await supabase
            .from("profiles")
            .upsert(payload, onConflict: "id")
            .execute()

        self.username = finalName
        self.avatarURLString = cleanAvatar
        self.visibility = visibility
    }

    func claimLegacy(accessCode: String) async throws -> String {
        let code = accessCode.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !code.isEmpty else {
            throw SessionError.invalidLegacyCode
        }

        let response: LegacyClaimResponse = try await supabase
            .rpc("claim_legacy_ratings", params: ["p_access_code": code])
            .execute()
            .value

        if response.success {
            hasClaimedLegacy = true
            if let user = supabase.auth.currentUser {
                try await refreshRemoteData(for: user)
            }
            return response.message
        }

        throw SessionError.custom(response.message)
    }

    func setCollection(_ isOn: Bool, for game: Game) async throws {
        if isOn {
            try await upsertSimpleRelation(table: "collection_items", gameID: game.id)
            collectionGameIDs.insert(game.id)
        } else {
            try await deleteSimpleRelation(table: "collection_items", gameID: game.id)
            collectionGameIDs.remove(game.id)
        }
    }

    func setWishlist(_ isOn: Bool, for game: Game) async throws {
        if isOn {
            try await upsertSimpleRelation(table: "wishlist_items", gameID: game.id)
            wishlistGameIDs.insert(game.id)
        } else {
            try await deleteSimpleRelation(table: "wishlist_items", gameID: game.id)
            wishlistGameIDs.remove(game.id)
        }
    }

    func setFavorite(_ isOn: Bool, for game: Game) async throws {
        if isOn {
            try await upsertSimpleRelation(table: "favorites", gameID: game.id)
            favoriteGameIDs.insert(game.id)
        } else {
            try await deleteSimpleRelation(table: "favorites", gameID: game.id)
            favoriteGameIDs.remove(game.id)
        }
    }

    func setRating(_ rating: Int?, for game: Game) async throws {
        guard let user = supabase.auth.currentUser else {
            throw SessionError.userNotFound
        }

        if let rating {
            guard (1...5).contains(rating) else {
                throw SessionError.invalidRating
            }

            let existing: [RatingRow] = try await supabase
                .from("ratings")
                .select("id, first_rated_at")
                .eq("user_id", value: user.id.uuidString)
                .eq("game_id", value: game.id)
                .limit(1)
                .execute()
                .value

            if let row = existing.first {
                try await supabase
                    .from("ratings")
                    .update(["rating": rating])
                    .eq("id", value: row.id.uuidString)
                    .execute()
            } else {
                let payload = RatingUpsert(userID: user.id, gameID: game.id, rating: rating)
                try await supabase
                    .from("ratings")
                    .insert(payload)
                    .execute()
            }

            ratingsByGameID[game.id] = rating
        } else {
            try await supabase
                .from("ratings")
                .delete()
                .eq("user_id", value: user.id.uuidString)
                .eq("game_id", value: game.id)
                .execute()

            ratingsByGameID.removeValue(forKey: game.id)
        }

        // ranking pode mudar
        try await reloadRankings()
    }

    func reloadData() async throws {
        guard let user = supabase.auth.currentUser else {
            throw SessionError.userNotFound
        }
        try await refreshRemoteData(for: user)
    }

    func searchCatalogGames(query: String) async throws -> [Game] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let escaped = trimmed.replacingOccurrences(of: "%", with: "")
        let rows: [CatalogGameRow] = try await supabase
            .from("games")
            .select("id, name, image_url, primary_category, min_players, max_players")
            .ilike("name", pattern: "%\(escaped)%")
            .eq("is_active", value: true)
            .order("name", ascending: true)
            .limit(50)
            .execute()
            .value

        return rows.map(mapCatalogRow).map { game in
            var updated = game
            updated.userRating = ratingsByGameID[game.id]
            return updated
        }
    }

    func fetchGameDetail(gameID: String) async throws -> GameDetail {
        let gameRows: [GameDetailRow] = try await supabase
            .from("games")
            .select("id, bgg_id, name, alt_name, subtitle, image_url, min_players, max_players, best_player_count, primary_category, primary_category_display, description, year_published, playing_time_min")
            .eq("id", value: gameID)
            .limit(1)
            .execute()
            .value

        guard let game = gameRows.first else {
            throw SessionError.custom("Jogo não encontrado.")
        }

        let contentRows: [GameContentRow] = try await supabase
            .from("game_content")
            .select("resumo_vaza, resumo_outros, birideck_markdown")
            .eq("game_id", value: gameID)
            .limit(1)
            .execute()
            .value

        let linksRows: [GameLinksRow] = try await supabase
            .from("game_external_links")
            .select("bgg_url, ludopedia_url, rules_url, pagat_url")
            .eq("game_id", value: gameID)
            .limit(1)
            .execute()
            .value

        let mechanicRows: [GameMechanicNameRow] = try await supabase
            .from("game_mechanics")
            .select("mechanics(name)")
            .eq("game_id", value: gameID)
            .execute()
            .value

        let content = contentRows.first
        let links = linksRows.first
        let bggObjectID = resolveBGGObjectID(gameID: gameID, bggID: game.bggID, bggURL: links?.bggURL)
        let bggMetadata: BggService.ThingMetadata?
        if let bggObjectID {
            bggMetadata = try? await bggService.fetchThingMetadata(gameID: bggObjectID)
        } else {
            bggMetadata = nil
        }
        var resolvedSummary = content?.summaryVaza ?? content?.summaryOther

        if resolvedSummary?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            let fallbackSummary: String?
            if let fromMetadata = bggMetadata?.translatedSummaryPT {
                fallbackSummary = fromMetadata
            } else if let bggObjectID {
                fallbackSummary = try? await bggService.fetchPortugueseSummary(gameID: bggObjectID)
            } else {
                fallbackSummary = nil
            }
            if let generatedSummary = fallbackSummary,
               !generatedSummary.isEmpty {
                resolvedSummary = generatedSummary
                let payload = GameContentSummaryUpsert(gameID: gameID, summaryOther: generatedSummary)
                _ = try? await supabase
                    .from("game_content")
                    .upsert(payload, onConflict: "game_id")
                    .execute()
            }
        }

        return GameDetail(
            id: game.id,
            name: game.name,
            altName: game.altName,
            subtitle: game.subtitle,
            imageURL: URL(string: game.imageURL ?? bggMetadata?.imageURL ?? ""),
            minPlayers: game.minPlayers ?? bggMetadata?.minPlayers,
            maxPlayers: game.maxPlayers ?? bggMetadata?.maxPlayers,
            playingTime: game.playingTimeMin ?? bggMetadata?.playingTime,
            yearPublished: game.yearPublished ?? bggMetadata?.yearPublished,
            bestPlayerCount: game.bestPlayerCount,
            category: game.primaryCategory,
            categoryDisplay: game.primaryCategoryDisplay,
            mechanics: mechanicRows.compactMap { $0.mechanics?.name },
            description: game.description ?? bggMetadata?.description,
            summary: resolvedSummary,
            biriDeck: content?.biriDeckMarkdown,
            links: GameExternalLinks(
                bgg: links?.bggURL,
                ludopedia: links?.ludopediaURL,
                rules: links?.rulesURL,
                pagat: links?.pagatURL
            )
        )
    }

    func bootstrap() async {
        guard let user = supabase.auth.currentUser else {
            clearState()
            return
        }

        applyUser(user)
        do {
            try await refreshRemoteData(for: user)
            isAuthenticated = true
        } catch {
            clearState()
        }
    }

    private func refreshRemoteData(for user: User) async throws {
        async let profileTask = try? fetchProfile(userID: user.id)
        async let catalogTask = try? fetchCatalogGames()
        async let rankingTask = try? fetchGamesRanking(days: nil)
        async let reviewersTask = try? fetchReviewersRanking(days: nil)
        async let ratingsTask = try? fetchRatings(userID: user.id)
        async let collectionTask = try? fetchSimpleRelation(table: "collection_items", userID: user.id)
        async let wishlistTask = try? fetchSimpleRelation(table: "wishlist_items", userID: user.id)
        async let favoritesTask = try? fetchSimpleRelation(table: "favorites", userID: user.id)

        let profileRows = await profileTask ?? []
        let catalogRows = await catalogTask ?? []
        let rankingRows = await rankingTask ?? []
        let reviewerRows = await reviewersTask ?? []
        let ratingRows = await ratingsTask ?? []
        let collectionRows = await collectionTask ?? []
        let wishlistRows = await wishlistTask ?? []
        let favoriteRows = await favoritesTask ?? []

        if let profile = profileRows.first {
            username = profile.username ?? username
            avatarURLString = profile.avatarURL ?? ""
            visibility = ProfileVisibility(rawValue: profile.visibility ?? "public") ?? .public
            hasClaimedLegacy = profile.claimedLegacy ?? false
        }

        ratingsByGameID = Dictionary(uniqueKeysWithValues: ratingRows.map { ($0.gameID, $0.rating) })
        collectionGameIDs = Set(collectionRows.map(\.gameID))
        wishlistGameIDs = Set(wishlistRows.map(\.gameID))
        favoriteGameIDs = Set(favoriteRows.map(\.gameID))

        catalogGames = catalogRows.map(mapCatalogRow).map { game in
            var updated = game
            updated.userRating = ratingsByGameID[game.id]
            return updated
        }

        rankedGames = rankingRows.enumerated().map { index, row in
            let playersRange: String = {
                switch (row.minPlayers, row.maxPlayers) {
                case let (min?, max?) where min == max: return "\(min)"
                case let (min?, max?): return "\(min)-\(max)"
                default: return "-"
                }
            }()

            return Game(
                id: row.gameID,
                name: row.name,
                rank: Int(row.rankPosition ?? Int64(index + 1)),
                imageURL: URL(string: row.imageURL ?? ""),
                category: "Carteado",
                playersRange: playersRange,
                communityRating: row.weightedRating ?? row.avgRating ?? 0,
                ratingCount: row.ratingCount ?? 0,
                userRating: ratingsByGameID[row.gameID]
            )
        }

        topReviewers = reviewerRows.map {
            Reviewer(username: $0.username, ratingCount: $0.ratedCount ?? 0, isLegacy: false)
        }
    }

    private func reloadRankings() async throws {
        let rankingRows: [RankingRow] = (try? await fetchGamesRanking(days: nil)) ?? []
        rankedGames = rankingRows.enumerated().map { index, row in
            let playersRange: String = {
                switch (row.minPlayers, row.maxPlayers) {
                case let (min?, max?) where min == max: return "\(min)"
                case let (min?, max?): return "\(min)-\(max)"
                default: return "-"
                }
            }()

            return Game(
                id: row.gameID,
                name: row.name,
                rank: Int(row.rankPosition ?? Int64(index + 1)),
                imageURL: URL(string: row.imageURL ?? ""),
                category: "Carteado",
                playersRange: playersRange,
                communityRating: row.weightedRating ?? row.avgRating ?? 0,
                ratingCount: row.ratingCount ?? 0,
                userRating: ratingsByGameID[row.gameID]
            )
        }
    }

    private func fetchProfile(userID: UUID) async throws -> [ProfileRow] {
        try await supabase
            .from("profiles")
            .select("username, avatar_url, visibility, claimed_legacy")
            .eq("id", value: userID.uuidString)
            .limit(1)
            .execute()
            .value
    }

    private func fetchCatalogGames() async throws -> [CatalogGameRow] {
        try await supabase
            .from("games")
            .select("id, name, image_url, primary_category, min_players, max_players")
            .eq("is_active", value: true)
            .order("name", ascending: true)
            .execute()
            .value
    }

    private func fetchGamesRanking(days: Int?) async throws -> [RankingRow] {
        if let days {
            return try await supabase
                .rpc("get_games_ranking", params: ["p_days": days, "p_m": 20])
                .execute()
                .value
        }

        return try await supabase
            .rpc("get_games_ranking")
            .execute()
            .value
    }

    private func fetchReviewersRanking(days: Int?) async throws -> [ReviewerRankingRow] {
        if let days {
            return try await supabase
                .rpc("get_reviewers_ranking", params: ["p_days": days])
                .execute()
                .value
        }

        return try await supabase
            .rpc("get_reviewers_ranking")
            .execute()
            .value
    }

    private func fetchRatings(userID: UUID) async throws -> [UserRatingRow] {
        try await supabase
            .from("ratings")
            .select("game_id, rating")
            .eq("user_id", value: userID.uuidString)
            .execute()
            .value
    }

    private func fetchSimpleRelation(table: String, userID: UUID) async throws -> [SimpleRelationRow] {
        try await supabase
            .from(table)
            .select("game_id")
            .eq("user_id", value: userID.uuidString)
            .execute()
            .value
    }

    private func upsertSimpleRelation(table: String, gameID: String) async throws {
        guard let user = supabase.auth.currentUser else {
            throw SessionError.userNotFound
        }

        let payload = SimpleRelationUpsert(userID: user.id, gameID: gameID)
        try await supabase
            .from(table)
            .upsert(payload, onConflict: "user_id,game_id")
            .execute()
    }

    private func deleteSimpleRelation(table: String, gameID: String) async throws {
        guard let user = supabase.auth.currentUser else {
            throw SessionError.userNotFound
        }

        try await supabase
            .from(table)
            .delete()
            .eq("user_id", value: user.id.uuidString)
            .eq("game_id", value: gameID)
            .execute()
    }

    private func mapCatalogRow(_ row: CatalogGameRow) -> Game {
        let playersRange: String = {
            switch (row.minPlayers, row.maxPlayers) {
            case let (min?, max?) where min == max: return "\(min)"
            case let (min?, max?): return "\(min)-\(max)"
            default: return "-"
            }
        }()

        return Game(
            id: row.id,
            name: row.name,
            rank: 0,
            imageURL: URL(string: row.imageURL ?? ""),
            category: row.primaryCategory ?? "Carteado",
            playersRange: playersRange,
            communityRating: 0,
            ratingCount: 0,
            userRating: nil
        )
    }
    
    private func resolveBGGObjectID(gameID: String, bggID: String?, bggURL: String?) -> String? {
        if let bggID, bggID.allSatisfy({ $0.isNumber }) {
            return bggID
        }
        if gameID.allSatisfy({ $0.isNumber }) {
            return gameID
        }
        
        guard let bggURL, !bggURL.isEmpty else { return nil }
        let pattern = "/boardgame/(\\d+)"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(bggURL.startIndex..<bggURL.endIndex, in: bggURL)
        guard let match = regex.firstMatch(in: bggURL, range: range),
              let idRange = Range(match.range(at: 1), in: bggURL) else { return nil }
        return String(bggURL[idRange])
    }

    private func applyUser(_ user: User) {
        email = user.email ?? ""
        if username == "Jogador" {
            username = user.email?.split(separator: "@").first.map(String.init) ?? "Jogador"
        }
    }

    private func clearState() {
        isAuthenticated = false
        email = ""
        username = "Jogador"
        avatarURLString = ""
        visibility = .public
        hasClaimedLegacy = false
        catalogGames = []
        rankedGames = []
        topReviewers = []
        collectionGameIDs = []
        wishlistGameIDs = []
        favoriteGameIDs = []
        ratingsByGameID = [:]
    }
}

enum ProfileVisibility: String, CaseIterable {
    case `public`
    case `private`
}

enum SessionError: LocalizedError {
    case invalidCredentials
    case invalidLegacyCode
    case invalidRating
    case userNotFound
    case custom(String)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Informe email e senha."
        case .invalidLegacyCode:
            return "Informe o código de legado."
        case .invalidRating:
            return "A nota deve ser entre 1 e 5."
        case .userNotFound:
            return "Usuário não encontrado na sessão."
        case .custom(let message):
            return message
        }
    }
}

private struct ProfileUpsert: Encodable {
    let id: UUID
    let username: String
    let avatarURL: String?
    let visibility: String

    enum CodingKeys: String, CodingKey {
        case id
        case username
        case avatarURL = "avatar_url"
        case visibility
    }
}

private struct SimpleRelationUpsert: Encodable {
    let userID: UUID
    let gameID: String

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case gameID = "game_id"
    }
}

private struct RatingUpsert: Encodable {
    let userID: UUID
    let gameID: String
    let rating: Int

    enum CodingKeys: String, CodingKey {
        case userID = "user_id"
        case gameID = "game_id"
        case rating
    }
}

private struct ProfileRow: Decodable {
    let username: String?
    let avatarURL: String?
    let visibility: String?
    let claimedLegacy: Bool?

    enum CodingKeys: String, CodingKey {
        case username
        case avatarURL = "avatar_url"
        case visibility
        case claimedLegacy = "claimed_legacy"
    }
}

private struct CatalogGameRow: Decodable {
    let id: String
    let name: String
    let imageURL: String?
    let primaryCategory: String?
    let minPlayers: Int?
    let maxPlayers: Int?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case imageURL = "image_url"
        case primaryCategory = "primary_category"
        case minPlayers = "min_players"
        case maxPlayers = "max_players"
    }
}

private struct RankingRow: Decodable {
    let gameID: String
    let name: String
    let imageURL: String?
    let minPlayers: Int?
    let maxPlayers: Int?
    let avgRating: Double?
    let weightedRating: Double?
    let ratingCount: Int?
    let rankPosition: Int64?

    enum CodingKeys: String, CodingKey {
        case gameID = "game_id"
        case name
        case imageURL = "image_url"
        case minPlayers = "min_players"
        case maxPlayers = "max_players"
        case avgRating = "avg_rating"
        case weightedRating = "weighted_rating"
        case ratingCount = "rating_count"
        case rankPosition = "rank_position"
    }
}

private struct ReviewerRankingRow: Decodable {
    let username: String
    let ratedCount: Int?

    enum CodingKeys: String, CodingKey {
        case username
        case ratedCount = "rated_count"
    }
}

private struct UserRatingRow: Decodable {
    let gameID: String
    let rating: Int

    enum CodingKeys: String, CodingKey {
        case gameID = "game_id"
        case rating
    }
}

private struct SimpleRelationRow: Decodable {
    let gameID: String

    enum CodingKeys: String, CodingKey {
        case gameID = "game_id"
    }
}

private struct RatingRow: Decodable {
    let id: UUID
    let firstRatedAt: String?

    enum CodingKeys: String, CodingKey {
        case id
        case firstRatedAt = "first_rated_at"
    }
}

private struct LegacyClaimResponse: Decodable {
    let success: Bool
    let message: String
    let count: Int?
}

private struct GameDetailRow: Decodable {
    let id: String
    let bggID: String?
    let name: String
    let altName: String?
    let subtitle: String?
    let imageURL: String?
    let minPlayers: Int?
    let maxPlayers: Int?
    let yearPublished: Int?
    let playingTimeMin: Int?
    let bestPlayerCount: Int?
    let primaryCategory: String?
    let primaryCategoryDisplay: String?
    let description: String?

    enum CodingKeys: String, CodingKey {
        case id, name, subtitle, description
        case bggID = "bgg_id"
        case altName = "alt_name"
        case imageURL = "image_url"
        case minPlayers = "min_players"
        case maxPlayers = "max_players"
        case yearPublished = "year_published"
        case playingTimeMin = "playing_time_min"
        case bestPlayerCount = "best_player_count"
        case primaryCategory = "primary_category"
        case primaryCategoryDisplay = "primary_category_display"
    }
}

private struct GameContentRow: Decodable {
    let summaryVaza: String?
    let summaryOther: String?
    let biriDeckMarkdown: String?

    enum CodingKeys: String, CodingKey {
        case summaryVaza = "resumo_vaza"
        case summaryOther = "resumo_outros"
        case biriDeckMarkdown = "birideck_markdown"
    }
}

private struct GameLinksRow: Decodable {
    let bggURL: String?
    let ludopediaURL: String?
    let rulesURL: String?
    let pagatURL: String?

    enum CodingKeys: String, CodingKey {
        case bggURL = "bgg_url"
        case ludopediaURL = "ludopedia_url"
        case rulesURL = "rules_url"
        case pagatURL = "pagat_url"
    }
}

private struct GameMechanicNameRow: Decodable {
    let mechanics: MechanicName?
}

private struct MechanicName: Decodable {
    let name: String?
}

private struct GameContentSummaryUpsert: Encodable {
    let gameID: String
    let summaryOther: String

    enum CodingKeys: String, CodingKey {
        case gameID = "game_id"
        case summaryOther = "resumo_outros"
    }
}
