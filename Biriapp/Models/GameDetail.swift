import Foundation

struct GameDetail: Identifiable, Hashable {
    let id: String
    let name: String
    let altName: String?
    let subtitle: String?
    let imageURL: URL?
    let minPlayers: Int?
    let maxPlayers: Int?
    let playingTime: Int?
    let yearPublished: Int?
    let bestPlayerCount: Int?
    let category: String?
    let categoryDisplay: String?
    let mechanics: [String]
    let description: String?
    let summary: String?
    let biriDeck: String?
    let links: GameExternalLinks
}

struct GameExternalLinks: Hashable {
    let bgg: String?
    let ludopedia: String?
    let rules: String?
    let pagat: String?
}
