import Foundation

enum EmojiRating {
    static func label(for rating: Int?) -> String {
        guard let rating else { return "Sem nota" }
        switch rating {
        case 1:
            return "💩"
        case 2:
            return "👍"
        case 3:
            return "✅"
        case 4:
            return "✅✅"
        case 5:
            return "✅✅✅"
        default:
            return "Sem nota"
        }
    }

    static let options: [(value: Int, emoji: String)] = [
        (1, "💩"),
        (2, "👍"),
        (3, "✅"),
        (4, "✅✅"),
        (5, "✅✅✅")
    ]
}
