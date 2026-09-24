import Foundation
@testable import Wastewise

final class MockWasteWiseRepository: WasteWiseRepository {
    var wasteItem: WasteItem?
    var schedule: CollectionSchedule?
    var shouldFail = false
    private(set) var submittedRequest: CleanupBookingRequest?
    private(set) var requestedAddress: ResidentialAddress?
    private(set) var requestedName: String?

    enum Failure: Error { case unavailable }

    func findWasteItem(named name: String) throws -> WasteItem? {
        requestedName = name
        if shouldFail { throw Failure.unavailable }
        return wasteItem
    }

    func collectionSchedule(for address: ResidentialAddress) throws -> CollectionSchedule? {
        requestedAddress = address
        if shouldFail { throw Failure.unavailable }
        return schedule
    }

    func submitCleanupBooking(_ request: CleanupBookingRequest) throws -> CleanupBookingConfirmation {
        if shouldFail { throw Failure.unavailable }
        submittedRequest = request
        return CleanupBookingConfirmation(reference: "WW-DEMO-001")
    }
}

final class MockAddressAutocomplete: AddressAutocompleteProviding {
    var onResults: (([AddressSuggestion]) -> Void)?
    var onError: ((String) -> Void)?
    var resolvedAddress = ResidentialAddress(street: "1 Test Street", suburb: "Parramatta", postcode: "2150")
    var failure: Error?
    var pendingResolution: CheckedContinuation<ResidentialAddress, Error>?
    var delayResolution = false
    private(set) var lastQuery: String?
    private(set) var selectedSuggestion: AddressSuggestion?

    func update(query: String) { lastQuery = query }
    func cancel() { }
    func resolve(_ suggestion: AddressSuggestion) async throws -> ResidentialAddress {
        selectedSuggestion = suggestion
        if let failure { throw failure }
        if delayResolution {
            return try await withCheckedThrowingContinuation { pendingResolution = $0 }
        }
        return resolvedAddress
    }
}
