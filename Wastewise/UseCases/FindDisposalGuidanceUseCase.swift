import Foundation

/// A resident can retry the offline catalogue or consult the council guide.
enum FindDisposalGuidanceError: LocalizedError, Equatable {
    case catalogueUnavailable

    var errorDescription: String? {
        "Couldn’t load disposal guidance. Try again or open the council’s A–Z guide below."
    }
}

/// Finds disposal advice within the resident’s selected disposal route.
/// Empty searches browse all items; every query word must match a name or a single
/// everyday alias. Instructions are excluded so warnings cannot become search matches.
/// Specialist items remain visible with their individual drop-off instructions.
struct FindDisposalGuidanceUseCase {
    let repository: any WasteWiseRepository

    func execute(query: String, stream: DisposalStream? = nil) throws -> [WasteItem] {
        do {
            return try repository.wasteItems(in: stream)
                .filter { $0.matchesSearch(query) }
                .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        } catch {
            throw FindDisposalGuidanceError.catalogueUnavailable
        }
    }
}
