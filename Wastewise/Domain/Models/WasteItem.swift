import Foundation

/// An item in the offline council-sourced disposal catalogue, linked to its disposal route.
struct WasteItem: Identifiable, Equatable {
    let id: String
    let name: String
    let disposalStream: DisposalStream
    let instruction: String
    var sourceURL: String? = nil
}

/// Household bin categories and additional disposal services. These are not all kerbside bins.
enum DisposalStream: String {
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
