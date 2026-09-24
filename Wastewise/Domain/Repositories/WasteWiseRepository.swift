import Foundation

/// Supplies household disposal information, collection schedules and simulated clean up receipts.
/// Use Cases enforce resident input and disposal rules before using these operations.
/// The current implementation combines local sample disposal data and simulated bookings
/// with live City of Parramatta collection zone information from ArcGIS.
protocol WasteWiseRepository {
    /// Finds a catalogue item by name, returning nil when it is unknown.
    /// A specialist item may be returned here; the classification Use Case prevents household bin advice.
    func findWasteItem(named name: String) throws -> WasteItem?
    /// Looks up collection information for a residential address, returning nil when no zone matches.
    /// Failures throw; a schedule without dates or day/area information is unusable to the Use Case.
    /// Live zone information describes a weekday and recycling area, not exact collection dates.
    func collectionSchedule(for address: ResidentialAddress) async throws -> CollectionSchedule?
    /// Processes a request already validated by the clean up Use Case and returns a demo receipt.
    /// This operation does not submit a booking to City of Parramatta or arrange a collection.
    func submitCleanupBooking(_ request: CleanupBookingRequest) throws -> CleanupBookingConfirmation
}
