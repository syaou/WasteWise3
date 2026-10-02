import Foundation
import CoreData

/// Combines a persistent Core Data disposal catalogue and simulated clean up receipts.
/// Despite its name, collection lookup delegates to the live City of Parramatta ArcGIS layer.
/// Item matching ignores case and surrounding whitespace; clean up submission always returns
/// `WW-DEMO-001` without contacting council. Use Cases perform request validation.
struct LocalWasteWiseRepository: WasteWiseRepository {
    private let catalogue: () throws -> DisposalCatalogueStore

    init() { catalogue = { try DisposalCatalogueStore.shared.get() } }
    init(catalogue: DisposalCatalogueStore) { self.catalogue = { catalogue } }

    func findWasteItem(named name: String) throws -> WasteItem? {
        let context = try catalogue().container.newBackgroundContext()
        return try context.performAndWait {
            let request = NSFetchRequest<NSManagedObject>(entityName: "WasteItemRecord")
            request.predicate = NSPredicate(format: "name ==[c] %@", name.trimmingCharacters(in: .whitespacesAndNewlines))
            request.fetchLimit = 1
            request.relationshipKeyPathsForPrefetching = ["category"]
            guard let record = try context.fetch(request).first else { return nil }
            guard let id = record.value(forKey: "identifier") as? String,
                  let name = record.value(forKey: "name") as? String,
                  let instruction = record.value(forKey: "instruction") as? String,
                  let category = record.value(forKey: "category") as? NSManagedObject,
                  let categoryName = category.value(forKey: "name") as? String,
                  let stream = DisposalStream(rawValue: categoryName) else {
                throw DisposalCatalogueStore.CatalogueError.invalidItem
            }
            return WasteItem(id: id, name: name, disposalStream: stream, instruction: instruction,
                             sourceURL: record.value(forKey: "sourceURL") as? String,
                             searchTerms: DisposalCatalogueSeed.searchTermsByID[id] ?? [])
        }
    }

    func allWasteItems() throws -> [WasteItem] {
        let context = try catalogue().container.newBackgroundContext()
        return try context.performAndWait {
            let request = NSFetchRequest<NSManagedObject>(entityName: "WasteItemRecord")
            request.relationshipKeyPathsForPrefetching = ["category"]
            return try context.fetch(request).map { record in
                guard let id = record.value(forKey: "identifier") as? String,
                      let name = record.value(forKey: "name") as? String,
                      let instruction = record.value(forKey: "instruction") as? String,
                      let category = record.value(forKey: "category") as? NSManagedObject,
                      let categoryName = category.value(forKey: "name") as? String,
                      let stream = DisposalStream(rawValue: categoryName) else {
                    throw DisposalCatalogueStore.CatalogueError.invalidItem
                }
                return WasteItem(id: id, name: name, disposalStream: stream, instruction: instruction,
                                 sourceURL: record.value(forKey: "sourceURL") as? String,
                                 searchTerms: DisposalCatalogueSeed.searchTermsByID[id] ?? [])
            }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
    }

    func collectionSchedule(for address: ResidentialAddress) async throws -> CollectionSchedule? {
        try await ArcGISBinService().fetchSchedule(for: address)
    }

    func submitCleanupBooking(_ request: CleanupBookingRequest) throws -> CleanupBookingConfirmation {
        CleanupBookingConfirmation(reference: "WW-DEMO-001")
    }
}
