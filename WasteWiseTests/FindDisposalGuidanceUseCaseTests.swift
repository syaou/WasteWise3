import XCTest
@testable import Wastewise

final class FindDisposalGuidanceUseCaseTests: XCTestCase {
    private func repository() -> MockWasteWiseRepository {
        let repository = MockWasteWiseRepository()
        repository.catalogueItems = [
            WasteItem(id: "dirty", name: "Pizza boxes dirty", disposalStream: .generalWaste,
                      instruction: "Keep out of recycling", searchTerms: ["greasy pizza box"]),
            WasteItem(id: "clean", name: "Pizza boxes clean", disposalStream: .recycling,
                      instruction: "Remove food first"),
            WasteItem(id: "battery", name: "Battery", disposalStream: .specialistDropOff,
                      instruction: "Take to a battery drop-off point", searchTerms: ["batteries"])
        ]
        return repository
    }

    func testResidentBrowsesAllRoutesWithAnEmptySearchInAlphabeticalOrder() throws {
        let items = try FindDisposalGuidanceUseCase(repository: repository()).execute(query: " \n ")
        XCTAssertEqual(items.map(\.id), ["battery", "clean", "dirty"])
    }

    func testResidentFindsEverydayNamesIgnoringAccentsCaseAndPunctuation() throws {
        let items = try FindDisposalGuidanceUseCase(repository: repository()).execute(query: " GRÉASY-pizza ")
        XCTAssertEqual(items.map(\.id), ["dirty"])
    }

    func testResidentSearchesOnlyTheSelectedDisposalRoute() throws {
        let repository = repository()
        let items = try FindDisposalGuidanceUseCase(repository: repository).execute(query: "pizza", stream: .recycling)
        XCTAssertEqual(items.map(\.id), ["clean"])
        // Check the query is sent to the repository, not only filtered in the screen.
        XCTAssertEqual(repository.requestedStream, .recycling)
    }

    func testWarningsAndWordsSplitAcrossAliasesDoNotProduceFalseMatches() throws {
        let useCase = FindDisposalGuidanceUseCase(repository: repository())
        XCTAssertTrue(try useCase.execute(query: "recycling").isEmpty)
        XCTAssertTrue(try useCase.execute(query: "dirty greasy").isEmpty)
        XCTAssertTrue(try useCase.execute(query: "unknown item").isEmpty)
    }

    func testSpecialistItemsKeepTheirSpecificAdvice() throws {
        let items = try FindDisposalGuidanceUseCase(repository: repository()).execute(query: "batteries")
        XCTAssertEqual(items.first?.disposalStream, .specialistDropOff)
        XCTAssertEqual(items.first?.instruction, "Take to a battery drop-off point")
    }

    func testUnavailableCatalogueReturnsADomainError() {
        let repository = repository()
        repository.shouldFail = true
        XCTAssertThrowsError(try FindDisposalGuidanceUseCase(repository: repository).execute(query: "pizza")) {
            XCTAssertEqual($0 as? FindDisposalGuidanceError, .catalogueUnavailable)
        }
    }

    @MainActor
    func testResidentChangesRouteClearsSearchAndRetriesAfterFailure() {
        let repository = repository()
        let model = ScanItemViewModel(repository: repository)
        model.loadCatalogue()
        XCTAssertEqual(model.filteredItems.count, 3)
        model.itemName = "pizza"
        XCTAssertEqual(model.filteredItems.count, 2)
        model.selectedStream = .generalWaste
        XCTAssertEqual(model.filteredItems.map(\.id), ["dirty"])
        model.itemName = ""
        XCTAssertEqual(model.filteredItems.map(\.id), ["dirty"])
        repository.shouldFail = true
        model.loadCatalogue()
        XCTAssertTrue(model.filteredItems.isEmpty)
        XCTAssertNotNil(model.catalogueError)
        repository.shouldFail = false
        model.loadCatalogue()
        XCTAssertNil(model.catalogueError)
        XCTAssertEqual(model.filteredItems.map(\.id), ["dirty"])
        model.selectedStream = nil
        XCTAssertEqual(model.filteredItems.count, 3)
    }
}
