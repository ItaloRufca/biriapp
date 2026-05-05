import Foundation

enum AppSeed {
    static let games: [Game] = [
        Game(id: "174430", name: "Gloomhaven", rank: 1, imageURL: nil, category: "Dungeon Crawler", playersRange: "1-4", communityRating: 4.8, ratingCount: 412, userRating: 5),
        Game(id: "167791", name: "Terraforming Mars", rank: 2, imageURL: nil, category: "Engine Builder", playersRange: "1-5", communityRating: 4.7, ratingCount: 533, userRating: nil),
        Game(id: "224517", name: "Brass: Birmingham", rank: 3, imageURL: nil, category: "Strategy", playersRange: "2-4", communityRating: 4.7, ratingCount: 490, userRating: 4),
        Game(id: "13", name: "Catan", rank: 4, imageURL: nil, category: "Family", playersRange: "3-4", communityRating: 4.0, ratingCount: 780, userRating: nil),
        Game(id: "68448", name: "7 Wonders", rank: 5, imageURL: nil, category: "Card Draft", playersRange: "2-7", communityRating: 4.3, ratingCount: 635, userRating: 4)
    ]

    static let reviewers: [Reviewer] = [
        Reviewer(username: "arete", ratingCount: 212, isLegacy: true),
        Reviewer(username: "julia", ratingCount: 183, isLegacy: false),
        Reviewer(username: "rafa", ratingCount: 161, isLegacy: true),
        Reviewer(username: "mari", ratingCount: 149, isLegacy: false),
        Reviewer(username: "leo", ratingCount: 130, isLegacy: false)
    ]

    static let collectionIDs: Set<String> = ["174430", "224517"]
    static let wishlistIDs: Set<String> = ["167791", "13"]
}
