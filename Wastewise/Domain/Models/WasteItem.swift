import Foundation

/// An item in the offline council-sourced disposal catalogue, linked to its disposal route.
struct WasteItem: Identifiable, Equatable {
    let id: String
    let name: String
    let disposalStream: DisposalStream
    let instruction: String
    var sourceURL: String? = nil
    var searchTerms: [String] = []

    /// Match everyday names, partial words and punctuation-insensitive phrases.
    func matchesSearch(_ query: String) -> Bool {
        let tokens = Self.searchTokens(query)
        guard !tokens.isEmpty else { return true }
        return ([name] + searchTerms).contains { term in
            let words = Self.searchTokens(term)
            return tokens.allSatisfy { token in words.contains { $0.contains(token) } }
        }
    }

    private static func searchTokens(_ value: String) -> [String] {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_AU"))
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { !$0.isEmpty }
    }
}

/// Household bin categories and additional disposal services. These are not all kerbside bins.
enum DisposalStream: String, CaseIterable {
    case recycling = "Recycling"
    case generalWaste = "General waste"
    case greenWaste = "Food and garden organics (FOGO)"
    case specialistDropOff = "Specialist drop-off"
    case communityRecyclingCentre = "Community Recycling Centre"
    case problemWaste = "Problem waste"
    case bulkyWaste = "Bulky waste"
}

/// Disposal instructions and their council source returned by the classification use case.
struct DisposalGuidance: Equatable {
    let itemName: String
    let disposalStream: DisposalStream
    let instruction: String
    var sourceURL: String? = nil
}
