import Foundation
import Combine

/// Presents disposal advice returned by the glossary Use Case.
@MainActor
final class ScanItemViewModel: ObservableObject {
    @Published var itemName = "" { didSet { loadCatalogue() } }
    @Published var selectedStream: DisposalStream? { didSet { loadCatalogue() } }
    @Published private(set) var filteredItems: [WasteItem] = []
    @Published private(set) var catalogueError: String?
    private let useCase: FindDisposalGuidanceUseCase

    init(repository: (any WasteWiseRepository)? = nil) {
        useCase = FindDisposalGuidanceUseCase(repository: repository ?? LocalWasteWiseRepository())
    }

    var glossaryLetters: [String] {
        Array(Set(filteredItems.map { String($0.name.prefix(1)).uppercased() })).sorted()
    }

    func loadCatalogue() {
        catalogueError = nil
        do { filteredItems = try useCase.execute(query: itemName, stream: selectedStream) }
        catch {
            filteredItems = []
            catalogueError = error.localizedDescription
        }
    }
}
