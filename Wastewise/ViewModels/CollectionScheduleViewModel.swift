import Foundation
import Combine

/// Presents collection information obtained through the collection Use Case for the saved household.
/// Cancels superseded lookups and ignores stale responses so a previous address's information
/// cannot replace the current result. The default repository uses live ArcGIS collection zones.
@MainActor
final class CollectionScheduleViewModel: ObservableObject {
    @Published private(set) var result: CollectionSchedule?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading = false
    private var lookupTask: Task<Void, Never>?
    private var lookupID = UUID()
    private let useCase: FindCollectionScheduleUseCase

    init(repository: (any WasteWiseRepository)? = nil) {
        useCase = FindCollectionScheduleUseCase(repository: repository ?? LocalWasteWiseRepository())
    }

    func findCollectionDates(address: ResidentialAddress) {
        clearResult()
        isLoading = true
        let id = lookupID
        lookupTask = Task {
            do {
                let schedule = try await useCase.execute(address: address)
                guard !Task.isCancelled, id == lookupID else { return }
                result = schedule
            } catch {
                guard !Task.isCancelled, id == lookupID else { return }
                errorMessage = error.localizedDescription
            }
            isLoading = false
            lookupTask = nil
        }
    }

    func clearResult() {
        lookupTask?.cancel()
        lookupTask = nil
        lookupID = UUID()
        isLoading = false
        result = nil
        errorMessage = nil
    }
}
