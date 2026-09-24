import Foundation
import MapKit

/// A possible residential address offered while a resident types.
/// A suggestion is not a verified service address: it must resolve to one Australian address
/// and pass address completeness validation before the shared store saves it.
struct AddressSuggestion: Identifiable, Equatable {
    let id: UUID
    let title: String
    let subtitle: String
}

/// Finds and resolves residential address suggestions independently of waste collection lookup.
/// Providers must reject non Australian or unresolved selections; the shared address store
/// checks completeness before saving. Tests can supply suggestions without contacting Apple Maps.
@MainActor
protocol AddressAutocompleteProviding: AnyObject {
    var onResults: (([AddressSuggestion]) -> Void)? { get set }
    var onError: ((String) -> Void)? { get set }
    func update(query: String)
    func resolve(_ suggestion: AddressSuggestion) async throws -> ResidentialAddress
    func cancel()
}

/// Uses Apple Maps address suggestions biased toward Parramatta and an Australian search query.
/// The geographic bias is not a country guarantee, so selection verifies an Australian country code.
/// Resolving an address does not establish City of Parramatta collection eligibility.
@MainActor
final class AddressAutocompleteService: NSObject, AddressAutocompleteProviding, MKLocalSearchCompleterDelegate {
    var onResults: (([AddressSuggestion]) -> Void)?
    var onError: ((String) -> Void)?
    private var completer: MKLocalSearchCompleter?
    private var completions: [UUID: MKLocalSearchCompletion] = [:]

    func update(query: String) {
        cancel()
        let completer = MKLocalSearchCompleter()
        completer.delegate = self
        completer.resultTypes = .address
        completer.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: -33.815, longitude: 151.005),
            latitudinalMeters: 60000, longitudinalMeters: 60000
        )
        completer.regionPriority = .default
        self.completer = completer
        // MapKit has no country-only completer filter. Bias the query and verify country on selection.
        completer.queryFragment = query + ", Australia"
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        guard completer === self.completer else { return }
        completions = [:]
        let suggestions = completer.results.prefix(8).map { completion in
            let id = UUID()
            completions[id] = completion
            return AddressSuggestion(id: id, title: completion.title, subtitle: completion.subtitle)
        }
        onResults?(suggestions)
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        guard completer === self.completer else { return }
        onError?("Couldn’t load addresses. Check your connection and try again.")
    }

    func resolve(_ suggestion: AddressSuggestion) async throws -> ResidentialAddress {
        guard let completion = completions[suggestion.id] else { throw AddressSelectionError.unavailable }
        let response = try await MKLocalSearch(request: MKLocalSearch.Request(completion: completion)).start()
        try Task.checkCancellation()
        guard response.mapItems.count == 1, let item = response.mapItems.first else {
            throw AddressSelectionError.unavailable
        }
        // Structured placemark components avoid guessing suburb/postcode from display strings.
        let placemark = item.placemark
        guard placemark.isoCountryCode == "AU" else { throw AddressSelectionError.outsideAustralia }
        let street = [placemark.subThoroughfare, placemark.thoroughfare].compactMap { $0 }.joined(separator: " ")
        return ResidentialAddress(street: street, suburb: placemark.locality ?? "", postcode: placemark.postalCode ?? "")
    }

    func cancel() {
        completer?.delegate = nil
        completer?.cancel()
        completer = nil
        completions = [:]
    }
}

/// Problems a resident may encounter when choosing a saved residential address.
/// Choose a more specific suggestion if it cannot be resolved, select an Australian address
/// for an overseas result, or include street, suburb and postcode when the result is incomplete.
enum AddressSelectionError: LocalizedError {
    case unavailable
    case outsideAustralia
    case incomplete

    var errorDescription: String? {
        switch self {
        case .unavailable: return "Address not found. Try a more specific address."
        case .outsideAustralia: return "Select an Australian address."
        case .incomplete: return "Choose a full address, including its postcode."
        }
    }
}
