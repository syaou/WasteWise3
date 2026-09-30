# Disposal catalogue database

Core Data stores two related entities: **DisposalCategory** (one) and **WasteItemRecord** (many). Categories represent disposal routes, not a fixed number of bins. The starter catalogue covers recycling, general waste, FOGO, specialist drop-off, Community Recycling Centre, problem waste and bulky waste.

Each item has a unique identifier, name, instructions, council source URL and required category relationship. The inverse category-to-items relationship uses cascade deletion. The store seeds an empty database in a single transaction; reopening it preserves saved records without duplicating the starter data.

## Architecture

Check an Item screen → ScanItemViewModel → ClassifyWasteItemUseCase → WasteWiseRepository protocol → LocalWasteWiseRepository → Core Data.

Only the data layer imports Core Data. The repository maps managed objects to domain values. The meaningful query `name ==[c] %@` finds an item's disposal route by name, ignoring case after trimming whitespace. Unknown names return no match; the use case translates failures to readable messages. Specialist battery handling continues to prevent household-bin guidance.

Core Data provides on-device, offline catalogue access. This is a small starter catalogue, not the entire council directory or a live feed. It does not provide cloud sync or preserve data after app deletion. Address/reminder storage is outside this change.

## Sources checked 27 September 2026

- Recycling, cardboard, glass and batteries: https://www.cityofparramatta.nsw.gov.au/residents/bins-waste-and-recycling/recycling/recycling-collection
- FOGO: https://www.cityofparramatta.nsw.gov.au/residents/bins-waste-and-recycling/fogo/a-z-fogo-list
- Other disposal routes: https://www.cityofparramatta.nsw.gov.au/residents/bins-waste-and-recycling/a-z-guide-to-waste-and-recycling
- General waste: https://www.cityofparramatta.nsw.gov.au/residents/bins-waste-and-recycling/your-bins/garbage-bin

Instructions are concise paraphrases. Each saved item includes its relevant source, displayed as a council guidance link when a lookup returns guidance.

## Verification

Existing use-case tests use MockWasteWiseRepository. Additional temporary-store integration tests verify lookup matching, all seven category relationships, source attribution and persistence after reopening without duplicated seeds. These tests do not touch the resident's database.
