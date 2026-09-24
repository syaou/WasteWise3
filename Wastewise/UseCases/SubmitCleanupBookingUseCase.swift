import Foundation

/// Problems a resident may encounter while preparing a simulated household clean up request.
/// Add a complete address, select an item, or remove paint and asbestos as appropriate.
/// Retry a failed simulation; no error or success response represents a booking sent to council.
enum SubmitCleanupBookingError: LocalizedError, Equatable {
    case incompleteAddress
    case noItemsSelected
    case prohibitedItems
    case serviceUnavailable

    var errorDescription: String? {
        switch self {
        case .incompleteAddress: return "Add your full address first."
        case .noItemsSelected: return "Select at least one item."
        case .prohibitedItems: return "Remove paint and asbestos. They need specialist disposal."
        case .serviceUnavailable: return "Couldn’t prepare your request. Please try again."
        }
    }
}

/// Prepares a simulated household clean up after checking the address and selected items.
/// Requires a complete address and at least one item, rejects paint and asbestos, and returns
/// a local demonstration receipt without booking a City of Parramatta collection.
struct SubmitCleanupBookingUseCase {
    let repository: any WasteWiseRepository

    func execute(request: CleanupBookingRequest) throws -> CleanupBookingConfirmation {
        guard request.address.isComplete else { throw SubmitCleanupBookingError.incompleteAddress }
        guard !request.items.isEmpty else { throw SubmitCleanupBookingError.noItemsSelected }
        guard !request.items.contains(where: { $0.isProhibited }) else { throw SubmitCleanupBookingError.prohibitedItems }
        do { return try repository.submitCleanupBooking(request) }
        catch { throw SubmitCleanupBookingError.serviceUnavailable }
    }
}
