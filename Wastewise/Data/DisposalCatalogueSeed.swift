import Foundation

/// These are disposal routes, not seven different household bins.
enum DisposalCatalogueSeed {
    static let recycling = "https://www.cityofparramatta.nsw.gov.au/residents/bins-waste-and-recycling/recycling/recycling-collection"
    static let fogo = "https://www.cityofparramatta.nsw.gov.au/residents/bins-waste-and-recycling/fogo/a-z-fogo-list"
    static let guide = "https://www.cityofparramatta.nsw.gov.au/residents/bins-waste-and-recycling/a-z-guide-to-waste-and-recycling"
    static let items: [WasteItem] = [
        WasteItem(id: "plastic-bag", name: "Plastic bag", disposalStream: .generalWaste,
                  instruction: "Put plastic bags in the red-lid general waste bin, not the yellow-lid recycling bin.",
                  sourceURL: "https://www.cityofparramatta.nsw.gov.au/residents/bins-waste-and-recycling/your-bins/garbage-bin"),
        WasteItem(id: "cardboard", name: "Cardboard box", disposalStream: .recycling,
                  instruction: "Flatten clean cardboard and place it in the yellow-lid recycling bin.", sourceURL: recycling),
        WasteItem(id: "glass-bottle", name: "Glass bottle", disposalStream: .recycling,
                  instruction: "Empty the bottle. Put it and its lid separately in the yellow-lid recycling bin.", sourceURL: recycling),
        WasteItem(id: "baking-paper", name: "Baking paper", disposalStream: .generalWaste,
                  instruction: "Use the red-lid general waste bin.", sourceURL: guide),
        WasteItem(id: "balloon", name: "Balloon", disposalStream: .generalWaste,
                  instruction: "Put unwanted balloons in the red-lid general waste bin.", sourceURL: guide),
        WasteItem(id: "grass", name: "Grass", disposalStream: .greenWaste,
                  instruction: "Put grass clippings in the green-lid food and garden organics (FOGO) bin.", sourceURL: fogo),
        WasteItem(id: "vegetable-scraps", name: "Vegetable scraps", disposalStream: .greenWaste,
                  instruction: "Put vegetable peels, cores and scraps in the green-lid FOGO bin. Remove packaging first.", sourceURL: fogo),
        WasteItem(id: "battery", name: "Battery", disposalStream: .specialistDropOff,
                  instruction: "Keep household batteries out of all kerbside bins. Use a council library battery drop-off or the council problem-waste service.", sourceURL: recycling),
        WasteItem(id: "toaster", name: "Toaster", disposalStream: .communityRecyclingCentre,
                  instruction: "Keep this small electrical appliance out of kerbside bins. Residents can take it to the Parramatta Community Recycling Centre.", sourceURL: guide),
        WasteItem(id: "automotive-chemicals", name: "Automotive chemicals", disposalStream: .problemWaste,
                  instruction: "Keep automotive chemicals in their original containers for a Household Chemical CleanOut event. Do not put them in kerbside bins.", sourceURL: guide),
        WasteItem(id: "barbecue", name: "Barbecue", disposalStream: .bulkyWaste,
                  instruction: "Consider reuse first. For an unusable barbecue, book a council bulky-waste collection and remove the gas bottle before collection.", sourceURL: guide)
    ]
}
