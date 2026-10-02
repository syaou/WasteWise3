import Foundation
import Combine

/// Presents the offline disposal glossary with everyday-name search.
/// The existing classification action retains its Use Case validation.
@MainActor
final class ScanItemViewModel: ObservableObject {
    @Published var itemName = ""
    @Published private(set) var result: DisposalGuidance?
    @Published private(set) var errorMessage: String?
    @Published private(set) var catalogue: [WasteItem] = []
    @Published private(set) var catalogueError: String?
    private let repository: any WasteWiseRepository
    private let useCase: ClassifyWasteItemUseCase

    init(repository: (any WasteWiseRepository)? = nil) {
        let repository = repository ?? LocalWasteWiseRepository()
        self.repository = repository
        useCase = ClassifyWasteItemUseCase(repository: repository)
    }

    var filteredItems: [WasteItem] {
        let query = itemName.trimmingCharacters(in: .whitespacesAndNewlines)
        return catalogue.filter { $0.matchesSearch(query) }
    }

    var glossaryLetters: [String] {
        Array(Set(filteredItems.map { String($0.name.prefix(1)).uppercased() })).sorted()
    }

    func loadCatalogue() {
        catalogueError = nil
        do { catalogue = try repository.allWasteItems() }
        catch { catalogueError = "The glossary couldn’t be loaded. Please try again." }
    }

    func checkDisposalGuidance() {
        result = nil
        errorMessage = nil
        do { result = try useCase.execute(itemName: itemName) }
        catch { errorMessage = error.localizedDescription }
    }
}
