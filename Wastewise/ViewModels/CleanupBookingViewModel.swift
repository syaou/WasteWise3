import Foundation
import Combine

/// Presents selected household items and the result of the simulated clean up Use Case.
/// Clearing an old confirmation retains the resident's item choices; a receipt is never a council booking.
@MainActor
final class CleanupBookingViewModel: ObservableObject {
    @Published var selectedItems: Set<CleanupItemType> = []
    @Published private(set) var result: CleanupBookingConfirmation?
    @Published private(set) var errorMessage: String?
    private let useCase: SubmitCleanupBookingUseCase

    init(repository: (any WasteWiseRepository)? = nil) {
        useCase = SubmitCleanupBookingUseCase(repository: repository ?? LocalWasteWiseRepository())
    }

    func submitBooking(address: ResidentialAddress) {
        clearResult()
        do { result = try useCase.execute(request: CleanupBookingRequest(address: address, items: selectedItems)) }
        catch { errorMessage = error.localizedDescription }
    }

    func clearResult() {
        result = nil
        errorMessage = nil
    }
}
