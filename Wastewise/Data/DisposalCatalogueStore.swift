import CoreData

/// Local, offline disposal catalogue. Only the data layer accesses managed objects.
final class DisposalCatalogueStore {
    static let shared: Result<DisposalCatalogueStore, Error> = Result { try DisposalCatalogueStore() }
    let container: NSPersistentContainer

    init(storeURL: URL? = nil) throws {
        guard let url = Bundle(for: DisposalCatalogueStore.self).url(forResource: "DisposalCatalogue", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: url) else { throw CatalogueError.unavailable }
        container = NSPersistentContainer(name: "DisposalCatalogue", managedObjectModel: model)
        if let storeURL { container.persistentStoreDescriptions = [NSPersistentStoreDescription(url: storeURL)] }
        for description in container.persistentStoreDescriptions {
            description.shouldAddStoreAsynchronously = false
            description.shouldMigrateStoreAutomatically = true
            description.shouldInferMappingModelAutomatically = true
        }
        var failure: Error?
        container.loadPersistentStores { _, error in failure = error }
        if let failure { throw failure }
        try seedMissingItems()
    }

    private func seedMissingItems() throws {
        let context = container.newBackgroundContext()
        try context.performAndWait {
            // Backfill new bundled items without replacing existing saved guidance.
            let records = try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "WasteItemRecord"))
            let existingIDs = Set(records.compactMap { $0.value(forKey: "identifier") as? String })
            var categories: [String: NSManagedObject] = [:]
            for category in try context.fetch(NSFetchRequest<NSManagedObject>(entityName: "DisposalCategory")) {
                if let name = category.value(forKey: "name") as? String { categories[name] = category }
            }
            for item in DisposalCatalogueSeed.items where !existingIDs.contains(item.id) {
                let category: NSManagedObject
                if let existing = categories[item.disposalStream.rawValue] { category = existing }
                else {
                    category = NSEntityDescription.insertNewObject(forEntityName: "DisposalCategory", into: context)
                    category.setValue(item.disposalStream.rawValue, forKey: "name")
                    categories[item.disposalStream.rawValue] = category
                }
                let record = NSEntityDescription.insertNewObject(forEntityName: "WasteItemRecord", into: context)
                record.setValue(item.id, forKey: "identifier")
                record.setValue(item.name, forKey: "name")
                record.setValue(item.instruction, forKey: "instruction")
                record.setValue(item.sourceURL, forKey: "sourceURL")
                record.setValue(category, forKey: "category")
            }
            if context.hasChanges { try context.save() }
        }
    }

    enum CatalogueError: Error { case unavailable, invalidItem }
}
