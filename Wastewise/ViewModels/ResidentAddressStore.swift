import Foundation
import Combine

/// Shares one resident address across Home, Collections and Clean Up and persists it between launches.
/// Only complete addresses are saved; autocomplete selections must first resolve through the provider.
/// Cancelled or superseded selections cannot replace the saved address. This UI state does not
/// establish council eligibility or replace validation in the collection and clean up Use Cases.
@MainActor
final class ResidentAddressStore: ObservableObject {
    @Published private var savedAddress: ResidentialAddress
    @Published private(set) var query = ""
    @Published private(set) var suggestions: [AddressSuggestion] = []
    @Published private(set) var autocompleteError: String?
    @Published private(set) var isResolving = false
    @Published private(set) var addressRevision = 0
    private let autocomplete: any AddressAutocompleteProviding
    private var selectionID = UUID()
    private let defaults: UserDefaults

    var address: ResidentialAddress { savedAddress }
    var street: String { address.street }
    var suburb: String { address.suburb }
    var postcode: String { address.postcode }
    var hasSavedAddress: Bool { address.isComplete }
    var formattedAddress: String { "\(street), \(suburb) \(postcode)" }

    init(defaults: UserDefaults = .standard, autocomplete: (any AddressAutocompleteProviding)? = nil) {
        self.autocomplete = autocomplete ?? AddressAutocompleteService()
        self.defaults = defaults
        savedAddress = ResidentialAddress(
            street: defaults.string(forKey: "residentAddress.street") ?? "",
            suburb: defaults.string(forKey: "residentAddress.suburb") ?? "",
            postcode: defaults.string(forKey: "residentAddress.postcode") ?? ""
        )
        query = savedAddress.isComplete ? formattedAddress : ""
        self.autocomplete.onResults = { [weak self] results in
            guard let self, !self.query.isEmpty, !self.isResolving else { return }
            self.suggestions = results
        }
        self.autocomplete.onError = { [weak self] message in
            self?.suggestions = []
            self?.autocompleteError = message
        }
    }

    /// Rejects incomplete drafts without replacing an existing saved address.
    @discardableResult
    func save(_ draft: ResidentialAddress) -> Bool {
        guard draft.isComplete else { return false }
        defaults.set(draft.street, forKey: "residentAddress.street")
        defaults.set(draft.suburb, forKey: "residentAddress.suburb")
        defaults.set(draft.postcode, forKey: "residentAddress.postcode")
        savedAddress = draft
        query = formattedAddress
        addressRevision += 1
        return true
    }

    func clear() {
        defaults.removeObject(forKey: "residentAddress.street")
        defaults.removeObject(forKey: "residentAddress.suburb")
        defaults.removeObject(forKey: "residentAddress.postcode")
        savedAddress = ResidentialAddress()
        endEditing()
        addressRevision += 1
    }

    func updateQuery(_ text: String) {
        selectionID = UUID()
        isResolving = false
        query = text
        suggestions = []
        autocompleteError = nil
        if text.trimmingCharacters(in: .whitespacesAndNewlines).count < 3 {
            autocomplete.cancel()
        } else {
            autocomplete.update(query: text)
        }
    }

    /// Resolves and validates a selected suggestion before replacing persisted UI state.
    func select(_ suggestion: AddressSuggestion) async -> Bool {
        let id = UUID()
        selectionID = id
        isResolving = true
        autocompleteError = nil
        suggestions = []
        do {
            let address = try await autocomplete.resolve(suggestion)
            guard id == selectionID, !Task.isCancelled else { return false }
            guard save(address) else { throw AddressSelectionError.incomplete }
            autocomplete.cancel()
            isResolving = false
            return true
        } catch {
            guard id == selectionID, !Task.isCancelled else { return false }
            isResolving = false
            autocompleteError = (error as? AddressSelectionError)?.localizedDescription
                ?? "Couldn’t load this address. Please try again."
            return false
        }
    }

    func endEditing() {
        selectionID = UUID()
        autocomplete.cancel()
        suggestions = []
        isResolving = false
        autocompleteError = nil
        query = hasSavedAddress ? formattedAddress : ""
    }

}
