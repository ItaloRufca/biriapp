import Foundation

struct Game: Identifiable, Hashable {
    let id: String
    let name: String
    let rank: Int
    let imageURL: URL?
    let category: String
    let playersRange: String
    let communityRating: Double
    let ratingCount: Int
    var userRating: Int?
}
