# Disposal glossary

The bundled catalogue contains 64 items. New entries were checked against City of Parramatta guidance on 1 October 2026. Each entry links to its council source; summaries are written for the app rather than copied from the website.

Sources:

- [Council A–Z guide](https://www.cityofparramatta.nsw.gov.au/residents/bins-waste-and-recycling/a-z-guide-to-waste-and-recycling) and individual item pages linked from the catalogue.
- [Garbage bin guide](https://www.cityofparramatta.nsw.gov.au/residents/bins-waste-and-recycling/your-bins/garbage-bin) for tissues, nappies and the general-waste fallback for soft plastics.
- [Community Recycling Centre](https://www.cityofparramatta.nsw.gov.au/residents/bins-waste-and-recycling/other-waste-services/community-recycling-centre) for current acceptance conditions and limits.
- [FOGO A–Z](https://www.cityofparramatta.nsw.gov.au/residents/bins-waste-and-recycling/fogo/a-z-fogo-list) for food and garden waste conditions.

Important distinctions remain visible in the instructions: clean versus dirty pizza boxes, empty versus nonempty aerosols, rigid plastic versus foam food containers, and eligible versus excluded polystyrene. FOGO advice assumes the household has a FOGO service. The catalogue is a curated offline selection, not the entire council directory or a live data feed.

Search uses item names and explicit everyday aliases, ignoring case, accents, punctuation and surrounding whitespace. Multiple search words must match within a name or alias; matching does not search disposal instructions, where an item might only appear as an exclusion. Examples include batteries, diapers, Styrofoam, BBQ and coffee grinds.

Aliases are bundled metadata keyed by stable item ID and attached by the repository. No Core Data schema migration is needed. Opening the store inserts missing catalogue records and reuses existing categories while preserving saved records. Updating guidance for an existing ID in a future release requires an explicit content-update policy; this backfill only adds missing items.

Validation covers persisted item counts, unique IDs, source links, everyday search names, ambiguous pizza searches, empty searches and reopening a partial catalogue without duplicates or overwriting saved instructions. See `WasteWiseTests/DisposalGlossaryTests.swift`.
