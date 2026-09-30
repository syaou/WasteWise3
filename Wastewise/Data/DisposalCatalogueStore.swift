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
        try seedIfEmpty()
    }

    private func seedIfEmpty() throws {
        let context = container.newBackgroundContext()
        try context.performAndWait {
            guard try context.count(for: NSFetchRequest<NSManagedObject>(entityName: "WasteItemRecord")) == 0 else { return }
            var categories: [String: NSManagedObject] = [:]
            for item in DisposalCatalogueSeed.items {
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
            try context.save()
        }
    }

    enum CatalogueError: Error { case unavailable, invalidItem }
}
