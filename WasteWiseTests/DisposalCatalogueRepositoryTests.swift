import CoreData
import XCTest
@testable import Wastewise

final class DisposalCatalogueRepositoryTests: XCTestCase {
    private var directory: URL!
    private var storeURL: URL { directory.appendingPathComponent("Catalogue.sqlite") }
    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    override func tearDownWithError() throws { try FileManager.default.removeItem(at: directory) }

    func testResidentFindsRecyclingGuidanceIgnoringCaseAndSpaces() throws {
        let repository = LocalWasteWiseRepository(catalogue: try DisposalCatalogueStore(storeURL: storeURL))
        XCTAssertEqual(try repository.findWasteItem(named: " CARDBOARD BOX ")?.disposalStream, .recycling)
        XCTAssertNil(try repository.findWasteItem(named: "Unknown item"))
    }

    func testCatalogueContainsAllSevenDisposalRoutesWithCouncilSources() throws {
        let repository = LocalWasteWiseRepository(catalogue: try DisposalCatalogueStore(storeURL: storeURL))
        let examples: [(String, DisposalStream)] = [("Cardboard box", .recycling), ("Baking paper", .generalWaste),
            ("Grass", .greenWaste), ("Battery", .specialistDropOff), ("Toaster", .communityRecyclingCentre),
            ("Automotive chemicals", .problemWaste), ("Barbecue", .bulkyWaste)]
        for (name, category) in examples {
            let item = try XCTUnwrap(repository.findWasteItem(named: name))
            XCTAssertEqual(item.disposalStream, category)
            XCTAssertTrue(item.sourceURL?.hasPrefix("https://www.cityofparramatta.nsw.gov.au/") == true)
        }
    }

    func testDisposalRecordsSurviveReopeningWithoutDuplicates() throws {
        try autoreleasepool {
            let store = try DisposalCatalogueStore(storeURL: storeURL)
            let context = store.container.newBackgroundContext()
            try context.performAndWait {
                let request = NSFetchRequest<NSManagedObject>(entityName: "WasteItemRecord")
                request.predicate = NSPredicate(format: "identifier == %@", "cardboard")
                let item = try XCTUnwrap(context.fetch(request).first)
                item.setValue("Persisted instruction", forKey: "instruction")
                try context.save()
            }
        }
        let reopened = try DisposalCatalogueStore(storeURL: storeURL)
        XCTAssertEqual(try LocalWasteWiseRepository(catalogue: reopened).findWasteItem(named: "Cardboard box")?.instruction, "Persisted instruction")
        let context = reopened.container.newBackgroundContext()
        try context.performAndWait {
            XCTAssertEqual(try context.count(for: NSFetchRequest<NSManagedObject>(entityName: "WasteItemRecord")), DisposalCatalogueSeed.items.count)
            XCTAssertEqual(try context.count(for: NSFetchRequest<NSManagedObject>(entityName: "DisposalCategory")), 7)
        }
    }

    func testBulkyWasteInstructionsPassThroughUseCaseWithMockRepository() throws {
        let repository = MockWasteWiseRepository()
        repository.wasteItem = WasteItem(id: "barbecue", name: "Barbecue", disposalStream: .bulkyWaste,
                                        instruction: "Book collection and remove gas bottle.")
        let result = try ClassifyWasteItemUseCase(repository: repository).execute(itemName: "Barbecue")
        XCTAssertEqual(result.disposalStream, .bulkyWaste)
        XCTAssertEqual(result.instruction, "Book collection and remove gas bottle.")
    }
}
