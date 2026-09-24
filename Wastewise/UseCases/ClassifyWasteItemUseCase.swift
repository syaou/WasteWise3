import Foundation

/// Problems a resident may encounter while checking a household item's disposal route.
/// Enter a name for missing input, try a known item or council guidance for an unknown item,
/// use specialist drop off for batteries, and retry if local guidance cannot be loaded.
enum ClassifyWasteItemError: LocalizedError, Equatable {
    case missingItemName
    case unrecognisedItem
    case specialistDisposalRequired
    case serviceUnavailable

    var errorDescription: String? {
        switch self {
        case .missingItemName: return "Enter an item name."
        case .unrecognisedItem: return "Item not found. Try one of the examples or check council guidance."
        case .specialistDisposalRequired: return "Keep batteries out of household bins. Use a battery drop off point."
        case .serviceUnavailable: return "Guidance is unavailable. Please try again."
        }
    }
}

/// Checks an item name against the local sample catalogue and returns household bin guidance.
/// Rejects blank or unknown names and prevents specialist waste from being recommended for a bin.
struct ClassifyWasteItemUseCase {
    let repository: any WasteWiseRepository

    func execute(itemName: String) throws -> DisposalGuidance {
        let name = itemName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { throw ClassifyWasteItemError.missingItemName }
        let item: WasteItem?
        do { item = try repository.findWasteItem(named: name) }
        catch { throw ClassifyWasteItemError.serviceUnavailable }
        guard let item else { throw ClassifyWasteItemError.unrecognisedItem }
        guard item.disposalStream != .specialistDropOff else {
            throw ClassifyWasteItemError.specialistDisposalRequired
        }
        return DisposalGuidance(itemName: item.name, disposalStream: item.disposalStream, instruction: item.instruction)
    }
}
