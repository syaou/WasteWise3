import Foundation

/// Combines local sample household disposal guidance and simulated clean up receipts.
/// Despite its name, collection lookup delegates to the live City of Parramatta ArcGIS layer.
/// Item matching ignores case and surrounding whitespace; clean up submission always returns
/// `WW-DEMO-001` without contacting council. Use Cases perform request validation.
struct LocalWasteWiseRepository: WasteWiseRepository {
    private let items = [
        WasteItem(id: "cardboard", name: "Cardboard box", disposalStream: .recycling,
                  instruction: "Flatten empty cardboard boxes for recycling."),
        WasteItem(id: "plastic-bag", name: "Plastic bag", disposalStream: .generalWaste,
                  instruction: "Put plastic bags in general waste, not recycling."),
        WasteItem(id: "grass", name: "Grass", disposalStream: .greenWaste,
                  instruction: "Put loose grass clippings in green waste."),
        WasteItem(id: "battery", name: "Battery", disposalStream: .specialistDropOff,
                  instruction: "Keep batteries out of household bins. Use a battery drop-off point.")
    ]

    func findWasteItem(named name: String) throws -> WasteItem? {
        items.first { $0.name.caseInsensitiveCompare(name.trimmingCharacters(in: .whitespacesAndNewlines)) == .orderedSame }
    }

    func collectionSchedule(for address: ResidentialAddress) async throws -> CollectionSchedule? {
        try await ArcGISBinService().fetchSchedule(for: address)
    }

    func submitCleanupBooking(_ request: CleanupBookingRequest) throws -> CleanupBookingConfirmation {
        CleanupBookingConfirmation(reference: "WW-DEMO-001")
    }
}
