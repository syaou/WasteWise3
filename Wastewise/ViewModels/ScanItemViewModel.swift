import Foundation
import Combine

/// Presents local sample household disposal guidance and recovery messages from the classification Use Case.
/// Specialist disposal decisions remain in the Use Case, not in the screen.
@MainActor
final class ScanItemViewModel: ObservableObject {
    @Published var itemName = ""
    @Published private(set) var result: DisposalGuidance?
    @Published private(set) var errorMessage: String?
    private let useCase: ClassifyWasteItemUseCase

    init(repository: (any WasteWiseRepository)? = nil) {
        useCase = ClassifyWasteItemUseCase(repository: repository ?? LocalWasteWiseRepository())
    }

    func checkDisposalGuidance() {
        result = nil
        errorMessage = nil
        do { result = try useCase.execute(itemName: itemName) }
        catch { errorMessage = error.localizedDescription }
    }
}
