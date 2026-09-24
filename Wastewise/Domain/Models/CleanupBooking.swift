import Foundation

/// Household item categories a resident can select for a simulated kerbside clean up request.
/// Paint and asbestos are prohibited by this prototype's rules and require specialist disposal.
/// The remaining categories do not establish eligibility for a real City of Parramatta booking.
enum CleanupItemType: String, CaseIterable, Identifiable {
    case furniture = "Furniture"
    case mattress = "Mattress"
    case appliance = "Appliance"
    case gardenWaste = "Garden waste"
    case paint = "Paint"
    case asbestos = "Asbestos"

    var id: String { rawValue }
    var isProhibited: Bool { self == .paint || self == .asbestos }
}

/// A resident's proposed household clean up, containing an address and selected item categories.
/// The submission Use Case requires a complete address, at least one item and no paint or asbestos.
/// This request is processed locally and is never sent to City of Parramatta.
struct CleanupBookingRequest {
    let address: ResidentialAddress
    let items: Set<CleanupItemType>
}

/// The receipt for a successfully validated simulated household clean up request.
/// The local repository returns the demonstration reference `WW-DEMO-001`; it is not a unique
/// council booking number and does not reserve or schedule a City of Parramatta collection.
struct CleanupBookingConfirmation: Equatable {
    let reference: String
}
