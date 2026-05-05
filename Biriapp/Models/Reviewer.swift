import Foundation

struct Reviewer: Identifiable, Hashable {
    let id: UUID = UUID()
    let username: String
    let ratingCount: Int
    let isLegacy: Bool
}
