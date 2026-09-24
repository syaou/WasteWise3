import Foundation

/// The household location used for collection lookup and a simulated clean up request.
/// A complete address has nonblank street and suburb names and a four digit postcode.
/// Completeness alone does not confirm the address exists or is serviced by City of Parramatta.
struct ResidentialAddress: Equatable {
    var street = ""
    var suburb = ""
    var postcode = ""

    /// Street and suburb need text; an Australian postcode needs exactly four ASCII digits.
    var isComplete: Bool {
        !street.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !suburb.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        postcode.count == 4 && postcode.allSatisfy { "0123456789".contains($0) }
    }
}

/// The household bin stream associated with a dated collection: recycling, general waste or green waste.
/// These categories describe bin collections, not specialist disposal or kerbside clean up requests.
/// The live ArcGIS zone response does not provide separate dates for these categories.
enum CollectionType: String {
    case recycling = "Recycling"
    case generalWaste = "General waste"
    case greenWaste = "FOGO"
}

/// A collection event pairing a household bin stream with a calendar date.
/// The collection Use Case derives 2026 events from a live zone and the published council calendar.
/// These are scheduled kerbside collections, not confirmation that a bin has been emptied.
struct BinCollection: Identifiable, Equatable {
    let id: String
    let type: CollectionType
    let date: Date
}

/// Household collection information associated with one residential address.
/// A usable result contains dated collections or both a collection day and recycling area.
/// ArcGIS supplies `DAY` and `WEEK` (an area label); the Use Case adds dates using the council’s
/// 2026 calendar. Other years are not inferred from that calendar.
struct CollectionSchedule: Equatable {
    let address: ResidentialAddress
    let collections: [BinCollection]
    var collectionDay: String? = nil
    var recyclingArea: String? = nil
}
