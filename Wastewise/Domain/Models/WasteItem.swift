import Foundation

/// A household item in WasteWise's local demonstration catalogue for City of Parramatta residents.
/// Its disposal stream determines whether household bin guidance is allowed; specialist waste
/// such as batteries must be directed to a drop off service instead. This is not live council advice.
struct WasteItem: Identifiable, Equatable {
    let id: String
    let name: String
    let disposalStream: DisposalStream
    let instruction: String
}

/// A disposal route for household waste: recycling, general waste, green waste or specialist drop off.
/// Specialist drop off items are excluded from household bin guidance by the classification Use Case.
enum DisposalStream: String {
    case recycling = "Recycling"
    case generalWaste = "General waste"
    case greenWaste = "Green waste"
    case specialistDropOff = "Specialist drop-off"
}

/// Disposal instructions returned to a resident for a recognised household bin item.
/// The classification Use Case creates this result only for non specialist streams.
/// Instructions come from local sample data, not a live City of Parramatta service.
struct DisposalGuidance: Equatable {
    let itemName: String
    let disposalStream: DisposalStream
    let instruction: String
}
