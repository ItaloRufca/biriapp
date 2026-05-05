import Foundation
import UIKit

struct BggService {
    private let session: URLSession = .shared
    
    struct ThingMetadata {
        let description: String?
        let translatedSummaryPT: String?
        let imageURL: String?
        let minPlayers: Int?
        let maxPlayers: Int?
        let playingTime: Int?
        let yearPublished: Int?
    }

    func searchGames(query: String, limit: Int = 20) async throws -> [Game] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
        guard let url = URL(string: "https://boardgamegeek.com/search/boardgame?q=\(encoded)") else {
            return []
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X)", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await session.data(for: request)
        let html = String(decoding: data, as: UTF8.self)

        let links = parseGameLinks(from: html)
        let unique = uniqueByID(links)
        let sliced = Array(unique.prefix(limit))

        return try await withThrowingTaskGroup(of: Game.self) { group in
            for item in sliced {
                group.addTask {
                    try await fetchGameDetails(id: item.id, fallbackName: item.name)
                }
            }

            var output: [Game] = []
            for try await game in group {
                output.append(game)
            }
            return output.sorted { $0.name < $1.name }
        }
    }

    func fetchPortugueseSummary(gameID: String) async throws -> String? {
        guard let rawDescription = try await fetchRawDescription(gameID: gameID) else {
            return nil
        }

        let cleanDescription = normalizeSummary(rawDescription)
        guard cleanDescription.count >= 80 else {
            return nil
        }

        if let translated = try await translateToPortuguese(cleanDescription) {
            let normalized = normalizeSummary(translated)
            return normalized.isEmpty ? cleanDescription : normalized
        }

        return cleanDescription
    }
    
    func fetchThingMetadata(gameID: String) async throws -> ThingMetadata? {
        guard let item = try await fetchThingItem(gameID: gameID) else { return nil }
        
        let rawDescription = item["description"] as? String
        let normalizedDescription = rawDescription.map(normalizeSummary)
        let translatedSummary: String?
        if let normalizedDescription, normalizedDescription.count >= 80 {
            translatedSummary = try await translateToPortuguese(normalizedDescription)
        } else {
            translatedSummary = nil
        }
        
        let imageURL = ((item["images"] as? [String: Any])?["original"] as? String) ?? (item["imageurl"] as? String)
        let minPlayers = intValue(item["minplayers"])
        let maxPlayers = intValue(item["maxplayers"])
        let playingTime = intValue(item["playingtime"])
        let yearPublished = intValue(item["yearpublished"])
        
        let xmlFallback: (minPlayers: Int?, maxPlayers: Int?, playingTime: Int?, yearPublished: Int?)?
        if minPlayers == nil || maxPlayers == nil || playingTime == nil || yearPublished == nil {
            xmlFallback = try? await fetchThingXMLMetadata(gameID: gameID)
        } else {
            xmlFallback = nil
        }
        
        return ThingMetadata(
            description: normalizedDescription,
            translatedSummaryPT: translatedSummary.map(normalizeSummary),
            imageURL: imageURL,
            minPlayers: minPlayers ?? xmlFallback?.minPlayers,
            maxPlayers: maxPlayers ?? xmlFallback?.maxPlayers,
            playingTime: playingTime ?? xmlFallback?.playingTime,
            yearPublished: yearPublished ?? xmlFallback?.yearPublished
        )
    }

    private func fetchRawDescription(gameID: String) async throws -> String? {
        try await fetchThingItem(gameID: gameID)?["description"] as? String
    }
    
    private func fetchThingItem(gameID: String) async throws -> [String: Any]? {
        guard let url = URL(string: "https://api.geekdo.com/api/geekitems?objectid=\(gameID)&objecttype=thing") else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, _) = try await session.data(for: request)
        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let rawItem = json["item"]
        else {
            return nil
        }
        
        if let map = rawItem as? [String: Any] { return map }
        if let list = rawItem as? [[String: Any]], let first = list.first { return first }
        return nil
    }

    private func translateToPortuguese(_ text: String) async throws -> String? {
        let encoded = text.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? text
        guard let url = URL(string: "https://translate.googleapis.com/translate_a/single?client=gtx&sl=auto&tl=pt&dt=t&q=\(encoded)") else {
            return nil
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await session.data(for: request)
        guard let root = try JSONSerialization.jsonObject(with: data) as? [Any],
              let chunks = root.first as? [Any]
        else {
            return nil
        }

        let translated = chunks.compactMap { chunk -> String? in
            guard let arr = chunk as? [Any], let segment = arr.first as? String else {
                return nil
            }
            return segment
        }.joined()

        return translated.isEmpty ? nil : translated
    }

    private func normalizeSummary(_ text: String) -> String {
        let withoutHTML = htmlToPlainText(text)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")

        let compact = withoutHTML
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return compact
    }
    
    private func intValue(_ value: Any?) -> Int? {
        if let int = value as? Int { return int }
        if let double = value as? Double { return Int(double) }
        if let number = value as? NSNumber { return number.intValue }
        if let string = value as? String {
            let digits = string.filter(\.isNumber)
            return Int(digits)
        }
        return nil
    }
    
    private func fetchThingXMLMetadata(gameID: String) async throws -> (minPlayers: Int?, maxPlayers: Int?, playingTime: Int?, yearPublished: Int?)? {
        guard let url = URL(string: "https://boardgamegeek.com/xmlapi2/thing?id=\(gameID)&stats=1") else {
            return nil
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("application/xml", forHTTPHeaderField: "Accept")
        request.setValue("Mozilla/5.0", forHTTPHeaderField: "User-Agent")
        
        let (data, _) = try await session.data(for: request)
        let xml = String(decoding: data, as: UTF8.self)
        
        let minPlayers = xmlInt(xml, tag: "minplayers")
        let maxPlayers = xmlInt(xml, tag: "maxplayers")
        let playingTime = xmlInt(xml, tag: "playingtime")
        let yearPublished = xmlInt(xml, tag: "yearpublished")
        
        return (minPlayers, maxPlayers, playingTime, yearPublished)
    }
    
    private func xmlInt(_ xml: String, tag: String) -> Int? {
        let pattern = "<\(tag)[^>]*value=\\\"([^\\\"]+)\\\""
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(xml.startIndex..<xml.endIndex, in: xml)
        guard let match = regex.firstMatch(in: xml, range: range),
              let valueRange = Range(match.range(at: 1), in: xml) else { return nil }
        return Int(String(xml[valueRange]))
    }

    private func htmlToPlainText(_ html: String) -> String {
        guard let data = html.data(using: .utf8) else { return html }
        if let attributed = try? NSAttributedString(
            data: data,
            options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding: String.Encoding.utf8.rawValue],
            documentAttributes: nil
        ) {
            return attributed.string
        }

        return html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
    }

    private func fetchGameDetails(id: String, fallbackName: String) async throws -> Game {
        guard let url = URL(string: "https://api.geekdo.com/api/geekitems?objectid=\(id)&objecttype=thing") else {
            return makeFallbackGame(id: id, name: fallbackName)
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, _) = try await session.data(for: request)
        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let rawItem = json["item"]
        else {
            return makeFallbackGame(id: id, name: fallbackName)
        }

        let item: [String: Any]
        if let map = rawItem as? [String: Any] {
            item = map
        } else if let list = rawItem as? [[String: Any]], let first = list.first {
            item = first
        } else {
            return makeFallbackGame(id: id, name: fallbackName)
        }

        let name = (item["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let imageURL = ((item["images"] as? [String: Any])?["original"] as? String) ?? (item["imageurl"] as? String)
        let minPlayers = item["minplayers"] as? Int
        let maxPlayers = item["maxplayers"] as? Int
        let playersRange: String

        if let minPlayers, let maxPlayers {
            playersRange = "\(minPlayers)-\(maxPlayers)"
        } else {
            playersRange = "-"
        }

        return Game(
            id: id,
            name: (name?.isEmpty == false ? name! : fallbackName),
            rank: 0,
            imageURL: URL(string: imageURL ?? ""),
            category: "BGG",
            playersRange: playersRange,
            communityRating: 0,
            ratingCount: 0,
            userRating: nil
        )
    }

    private func makeFallbackGame(id: String, name: String) -> Game {
        Game(
            id: id,
            name: name,
            rank: 0,
            imageURL: nil,
            category: "BGG",
            playersRange: "-",
            communityRating: 0,
            ratingCount: 0,
            userRating: nil
        )
    }

    private func parseGameLinks(from html: String) -> [(id: String, name: String)] {
        let pattern = "href=\\\"/boardgame/(\\\\d+)/[^\\\"]*\\\"[^>]*>([^<]+)</a>"
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        let fullRange = NSRange(location: 0, length: (html as NSString).length)
        let matches = regex.matches(in: html, range: fullRange)

        return matches.compactMap { match in
            guard match.numberOfRanges >= 3 else { return nil }

            let idRange = match.range(at: 1)
            let nameRange = match.range(at: 2)
            guard
                let swiftIDRange = Range(idRange, in: html),
                let swiftNameRange = Range(nameRange, in: html)
            else {
                return nil
            }

            let id = String(html[swiftIDRange])
            let rawName = String(html[swiftNameRange])
            let name = rawName
                .replacingOccurrences(of: "&amp;", with: "&")
                .replacingOccurrences(of: "&quot;", with: "\"")
                .replacingOccurrences(of: "&#39;", with: "'")
                .trimmingCharacters(in: .whitespacesAndNewlines)

            return (id: id, name: name)
        }
    }

    private func uniqueByID(_ items: [(id: String, name: String)]) -> [(id: String, name: String)] {
        var seen: Set<String> = []
        var output: [(id: String, name: String)] = []

        for item in items where !seen.contains(item.id) {
            seen.insert(item.id)
            output.append(item)
        }

        return output
    }
}
