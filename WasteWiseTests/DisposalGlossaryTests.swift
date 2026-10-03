import CoreData
import XCTest
@testable import Wastewise

final class DisposalGlossaryTests: XCTestCase {
    @MainActor
    func testEverydayNamesAndConditionalItems() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try DisposalCatalogueStore(storeURL: directory.appendingPathComponent("Catalogue.sqlite"))
        let model = ScanItemViewModel(repository: LocalWasteWiseRepository(catalogue: store))
        model.loadCatalogue()
        let catalogue = model.filteredItems
        XCTAssertNil(model.catalogueError)
        XCTAssertGreaterThanOrEqual(catalogue.count, 50)
        XCTAssertEqual(Set(catalogue.map(\.id)).count, catalogue.count)
        for (query, id) in [(" BATTERIES ", "battery"), ("diapers", "nappies"),
                            ("Styrofoam", "polystyrene-packaging"), ("BBQ", "barbecue"),
                            ("coffee grinds", "coffee-grinds-without-pods-or-other-packaging"),
                            ("T-SHIRTS", "clothing-end-of-life-clothing")] {
            model.itemName = query
            XCTAssertTrue(model.filteredItems.contains { $0.id == id }, query)
        }
        model.itemName = "pizza box"
        XCTAssertEqual(Set(model.filteredItems.map(\.disposalStream)), [.generalWaste, .recycling])
        model.itemName = "greasy pizza box"
        XCTAssertEqual(model.filteredItems.map(\.id), ["pizza-boxes-dirty"])
        model.itemName = "no such item"
        XCTAssertTrue(model.filteredItems.isEmpty)
        model.itemName = " "
        XCTAssertEqual(model.filteredItems.count, catalogue.count)
        XCTAssertTrue(catalogue.allSatisfy { $0.sourceURL?.hasPrefix("https://www.cityofparramatta.nsw.gov.au/") == true })
    }

    func testRepositoryQueriesItemsThroughTheirDisposalCategory() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = try DisposalCatalogueStore(storeURL: directory.appendingPathComponent("Catalogue.sqlite"))
        let repository = LocalWasteWiseRepository(catalogue: store)
        let allItems = try repository.allWasteItems()
        for stream in DisposalStream.allCases {
            let items = try repository.wasteItems(in: stream)
            XCTAssertFalse(items.isEmpty, stream.rawValue)
            XCTAssertEqual(Set(items.map(\.id)), Set(allItems.filter { $0.disposalStream == stream }.map(\.id)))
        }
    }

    func testBackfillAddsItemsToExistingStoreWithoutReplacingGuidanceOrDuplicatingCategories() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Catalogue.sqlite")
        try autoreleasepool {
            let store = try DisposalCatalogueStore(storeURL: url)
            let context = store.container.newBackgroundContext()
            try context.performAndWait {
                let records = try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "WasteItemRecord"))
                for record in records {
                    if record.value(forKey: "identifier") as? String == "cardboard" {
                        record.setValue("Saved instruction", forKey: "instruction")
                    } else { context.delete(record) }
                }
                try context.save()
            }
        }
        for _ in 0..<2 {
            let store = try DisposalCatalogueStore(storeURL: url)
            let repository = LocalWasteWiseRepository(catalogue: store)
            XCTAssertEqual(try repository.allWasteItems().count, DisposalCatalogueSeed.items.count)
            XCTAssertEqual(try repository.findWasteItem(named: "Cardboard box")?.instruction, "Saved instruction")
            let context = store.container.newBackgroundContext()
            try context.performAndWait {
                XCTAssertEqual(try context.count(for: NSFetchRequest<NSManagedObject>(entityName: "DisposalCategory")), 7)
            }
        }
    }
}
