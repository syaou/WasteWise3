import XCTest
import Combine
@testable import Wastewise

@MainActor
final class WasteWiseUseCaseTests: XCTestCase {
    private var address: ResidentialAddress {
        ResidentialAddress(street: "1 Sample Street", suburb: "Parramatta", postcode: "2150")
    }

    func test_classifyWasteItem_returnsRecyclingGuidance_forCardboard() throws {
        let repository = MockWasteWiseRepository()
        repository.wasteItem = WasteItem(id: "cardboard", name: "Cardboard box", disposalStream: .recycling, instruction: "Flatten the box.")
        let result = try ClassifyWasteItemUseCase(repository: repository).execute(itemName: " Cardboard box ")
        XCTAssertEqual(result.disposalStream, .recycling)
        XCTAssertEqual(result.instruction, "Flatten the box.")
        XCTAssertEqual(repository.requestedName, "Cardboard box")
    }

    func test_classifyWasteItem_rejectsEmptyName() {
        let repository = MockWasteWiseRepository()
        XCTAssertThrowsError(try ClassifyWasteItemUseCase(repository: repository).execute(itemName: " \n ")) {
            XCTAssertEqual($0 as? ClassifyWasteItemError, .missingItemName)
        }
        XCTAssertNil(repository.requestedName)
    }

    func test_classifyWasteItem_rejectsUnknownItem() {
        XCTAssertThrowsError(try ClassifyWasteItemUseCase(repository: MockWasteWiseRepository()).execute(itemName: "Mystery item")) {
            XCTAssertEqual($0 as? ClassifyWasteItemError, .unrecognisedItem)
        }
    }

    func test_classifyWasteItem_requiresSpecialistDisposal_forBattery() {
        let repository = MockWasteWiseRepository()
        repository.wasteItem = WasteItem(id: "battery", name: "Battery", disposalStream: .specialistDropOff, instruction: "Use specialist disposal.")
        XCTAssertThrowsError(try ClassifyWasteItemUseCase(repository: repository).execute(itemName: "Battery")) {
            XCTAssertEqual($0 as? ClassifyWasteItemError, .specialistDisposalRequired)
        }
    }

    func test_findCollectionSchedule_returnsSchedule_forValidAddress() async throws {
        let repository = MockWasteWiseRepository()
        repository.schedule = CollectionSchedule(address: address, collections: [BinCollection(id: "sample", type: .recycling, date: .distantFuture)])
        let result = try await FindCollectionScheduleUseCase(repository: repository).execute(address: address)
        XCTAssertEqual(result, repository.schedule)
        XCTAssertEqual(repository.requestedAddress, address)
    }

    func test_findCollectionSchedule_rejectsIncompleteAddress() async throws {
        let repository = MockWasteWiseRepository()
        let useCase = FindCollectionScheduleUseCase(repository: repository)
        let invalidAddresses = [
            ResidentialAddress(street: " ", suburb: "Parramatta", postcode: "2150"),
            ResidentialAddress(street: "1 Sample Street", suburb: "\n", postcode: "2150"),
            ResidentialAddress(street: "1 Sample Street", suburb: "Parramatta", postcode: "215"),
            ResidentialAddress(street: "1 Sample Street", suburb: "Parramatta", postcode: "21500"),
            ResidentialAddress(street: "1 Sample Street", suburb: "Parramatta", postcode: "21a0")
        ]
        for address in invalidAddresses {
            await assertCollectionError({ try await useCase.execute(address: address) }) {
                XCTAssertEqual($0 as? FindCollectionScheduleError, .incompleteAddress)
            }
        }
        XCTAssertNil(repository.requestedAddress)
    }

    func test_findCollectionSchedule_rejectsUnsupportedAddress() async throws {
        let repository = MockWasteWiseRepository()
        let unsupported = ResidentialAddress(street: "1 Sample Street", suburb: "Sydney", postcode: "2000")
        await assertCollectionError({ try await FindCollectionScheduleUseCase(repository: repository).execute(address: unsupported) }) {
            XCTAssertEqual($0 as? FindCollectionScheduleError, .unsupportedAddress)
        }
        XCTAssertEqual(repository.requestedAddress, unsupported)
    }

    func test_findCollectionSchedule_reportsUnavailableData_forEmptySchedule() async throws {
        let repository = MockWasteWiseRepository()
        repository.schedule = CollectionSchedule(address: address, collections: [])
        await assertCollectionError({ try await FindCollectionScheduleUseCase(repository: repository).execute(address: address) }) {
            XCTAssertEqual($0 as? FindCollectionScheduleError, .dataUnavailable)
        }
    }

    func test_submitCleanupBooking_returnsDemoConfirmation_forValidRequest() throws {
        let repository = MockWasteWiseRepository()
        let request = CleanupBookingRequest(address: address, items: [.furniture, .mattress])
        let result = try SubmitCleanupBookingUseCase(repository: repository).execute(request: request)
        XCTAssertEqual(result.reference, "WW-DEMO-001")
        XCTAssertEqual(repository.submittedRequest?.address, address)
        XCTAssertEqual(repository.submittedRequest?.items, request.items)
    }

    func test_submitCleanupBooking_rejectsNoItems() {
        let repository = MockWasteWiseRepository()
        XCTAssertThrowsError(try SubmitCleanupBookingUseCase(repository: repository).execute(request: CleanupBookingRequest(address: address, items: []))) {
            XCTAssertEqual($0 as? SubmitCleanupBookingError, .noItemsSelected)
        }
        XCTAssertNil(repository.submittedRequest)
    }

    func test_submitCleanupBooking_rejectsIncompleteAddress() {
        let repository = MockWasteWiseRepository()
        XCTAssertThrowsError(try SubmitCleanupBookingUseCase(repository: repository).execute(request: CleanupBookingRequest(address: ResidentialAddress(), items: [.furniture]))) {
            XCTAssertEqual($0 as? SubmitCleanupBookingError, .incompleteAddress)
        }
        XCTAssertNil(repository.submittedRequest)
    }

    func test_submitCleanupBooking_rejectsPaintAndAsbestos() {
        let repository = MockWasteWiseRepository()
        for prohibited: CleanupItemType in [.paint, .asbestos] {
            XCTAssertThrowsError(try SubmitCleanupBookingUseCase(repository: repository).execute(request: CleanupBookingRequest(address: address, items: [.furniture, prohibited]))) {
                XCTAssertEqual($0 as? SubmitCleanupBookingError, .prohibitedItems)
            }
        }
        XCTAssertNil(repository.submittedRequest)
    }

    func test_useCases_reportRecoveryErrors_whenRepositoryFails() async throws {
        let repository = MockWasteWiseRepository()
        repository.shouldFail = true
        XCTAssertThrowsError(try ClassifyWasteItemUseCase(repository: repository).execute(itemName: "Cardboard box")) {
            XCTAssertEqual($0 as? ClassifyWasteItemError, .serviceUnavailable)
        }
        await assertCollectionError({ try await FindCollectionScheduleUseCase(repository: repository).execute(address: address) }) {
            XCTAssertEqual($0 as? FindCollectionScheduleError, .dataUnavailable)
        }
        XCTAssertThrowsError(try SubmitCleanupBookingUseCase(repository: repository).execute(request: CleanupBookingRequest(address: address, items: [.furniture]))) {
            XCTAssertEqual($0 as? SubmitCleanupBookingError, .serviceUnavailable)
        }
        XCTAssertNil(repository.submittedRequest)
    }

    private func assertCollectionError(
        _ operation: () async throws -> CollectionSchedule,
        file: StaticString = #filePath,
        line: UInt = #line,
        check: (Error) -> Void
    ) async {
        do {
            _ = try await operation()
            XCTFail("Expected collection lookup to fail", file: file, line: line)
        } catch { check(error) }
    }

    func test_findCollectionSchedule_returnsDayAndArea_withoutInventingDates() async throws {
        let repository = MockWasteWiseRepository()
        repository.schedule = CollectionSchedule(address: address, collections: [], collectionDay: "MONDAY", recyclingArea: "A")
        let result = try await FindCollectionScheduleUseCase(repository: repository).execute(address: address)
        XCTAssertEqual(result.collectionDay, "MONDAY")
        XCTAssertEqual(result.recyclingArea, "A")
        XCTAssertTrue(result.collections.isEmpty)
    }

    func test_arcGIS_decodesDayAndWeek() throws {
        let data = Data(#"{"features":[{"attributes":{"DAY":"Monday","WEEK":"A"}}]}"#.utf8)
        let result = try ArcGISBinService.decodeSchedule(data, address: address)
        XCTAssertEqual(result?.collectionDay, "Monday")
        XCTAssertEqual(result?.recyclingArea, "A")
    }

    func test_arcGIS_returnsNoSchedule_forNoMatchingZone() throws {
        let result = try ArcGISBinService.decodeSchedule(Data(#"{"features":[]}"#.utf8), address: address)
        XCTAssertNil(result)
    }

    func test_arcGIS_rejectsErrorsNullFieldsAndAmbiguousZones() {
        for json in [
            #"{"error":{"code":400}}"#,
            #"{"features":[{"attributes":{"DAY":null,"WEEK":"A"}}]}"#,
            #"{"features":[{"attributes":{"DAY":"Monday","WEEK":""}}]}"#,
            #"{"features":[{"attributes":{"DAY":"Monday","WEEK":"A"}},{"attributes":{"DAY":"Tuesday","WEEK":"B"}}]}"#,
            "invalid JSON"
        ] {
            XCTAssertThrowsError(try ArcGISBinService.decodeSchedule(Data(json.utf8), address: address))
        }
    }


    func test_selectAddress_savesCompleteAddressAndHidesSuggestions() async {
        let suite = "WasteWiseTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let provider = MockAddressAutocomplete()
        let store = ResidentAddressStore(defaults: defaults, autocomplete: provider)
        let suggestion = AddressSuggestion(id: UUID(), title: "1 Test Street", subtitle: "Parramatta NSW 2150, Australia")
        store.updateQuery("1 Test")
        provider.onResults?([suggestion])
        XCTAssertEqual(store.suggestions, [suggestion])
        let revision = store.addressRevision
        let selected = await store.select(suggestion)
        XCTAssertTrue(selected)
        XCTAssertEqual(provider.selectedSuggestion, suggestion)
        XCTAssertEqual(store.address, provider.resolvedAddress)
        XCTAssertEqual(store.query, "1 Test Street, Parramatta 2150")
        XCTAssertTrue(store.suggestions.isEmpty)
        XCTAssertFalse(store.isResolving)
        XCTAssertEqual(store.addressRevision, revision + 1)
        let reopened = ResidentAddressStore(defaults: defaults, autocomplete: MockAddressAutocomplete())
        XCTAssertEqual(reopened.address, store.address)
    }

    func test_selectAddress_preservesSavedAddress_whenIncompleteOrOutsideAustralia() async {
        let suite = "WasteWiseTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let provider = MockAddressAutocomplete()
        let store = ResidentAddressStore(defaults: defaults, autocomplete: provider)
        store.save(address)
        let revision = store.addressRevision
        let suggestion = AddressSuggestion(id: UUID(), title: "Incomplete", subtitle: "")
        provider.resolvedAddress = ResidentialAddress()
        let incomplete = await store.select(suggestion)
        XCTAssertFalse(incomplete)
        XCTAssertEqual(store.address, address)
        XCTAssertNotNil(store.autocompleteError)
        provider.failure = AddressSelectionError.outsideAustralia
        let overseas = await store.select(suggestion)
        XCTAssertFalse(overseas)
        XCTAssertEqual(store.address, address)
        XCTAssertEqual(store.addressRevision, revision)
    }

    func test_cancelAddressEditing_preservesSavedAddress() {
        let suite = "WasteWiseTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let provider = MockAddressAutocomplete()
        let store = ResidentAddressStore(defaults: defaults, autocomplete: provider)
        store.save(address)
        store.updateQuery("Another street")
        XCTAssertEqual(provider.lastQuery, "Another street")
        store.endEditing()
        XCTAssertEqual(store.address, address)
        XCTAssertEqual(store.query, store.formattedAddress)
        XCTAssertTrue(store.suggestions.isEmpty)
    }

    func test_selectAddress_ignoresResolutionAfterUserEditsAgain() async {
        let suite = "WasteWiseTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let provider = MockAddressAutocomplete()
        provider.delayResolution = true
        let store = ResidentAddressStore(defaults: defaults, autocomplete: provider)
        let suggestion = AddressSuggestion(id: UUID(), title: "1 Test Street", subtitle: "Parramatta")
        let task = Task { await store.select(suggestion) }
        while provider.pendingResolution == nil { await Task.yield() }
        store.updateQuery("Different address")
        provider.pendingResolution?.resume(returning: provider.resolvedAddress)
        let selected = await task.value
        XCTAssertFalse(selected)
        XCTAssertFalse(store.hasSavedAddress)
        XCTAssertEqual(store.query, "Different address")
    }


    func test_collectionCalendar_matchesPublishedSeptemberRecyclingWeeks() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Australia/Sydney")!
        for (area, recyclingDays) in [("Area 1", [8, 22]), ("Area 2", [1, 15, 29])] {
            let dates = FindCollectionScheduleUseCase.collectionDates2026(day: "Tuesday", area: area)
            let september = dates.filter { calendar.component(.month, from: $0.date) == 9 }
            XCTAssertEqual(september.filter { $0.type == .recycling }.map { calendar.component(.day, from: $0.date) }, recyclingDays)
            XCTAssertEqual(september.filter { $0.type == .generalWaste }.count, 5)
            XCTAssertEqual(september.filter { $0.type == .greenWaste }.count, 5)
        }
    }

    func test_collectionCalendar_keepsWeekdayAcrossDaylightSavingAndYearBoundaries() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Australia/Sydney")!
        let dates = FindCollectionScheduleUseCase.collectionDates2026(day: " Thursday ", area: "AREA 1")
        XCTAssertEqual(dates.filter { $0.type == .generalWaste }.count, 53)
        XCTAssertEqual(dates.filter { $0.type == .recycling }.count, 27)
        XCTAssertTrue(dates.allSatisfy { calendar.component(.year, from: $0.date) == 2026 && calendar.component(.weekday, from: $0.date) == 5 })
        XCTAssertEqual(Set(dates.map(\.id)).count, dates.count)
        let recycling = dates.filter { $0.type == .recycling }
        XCTAssertEqual(calendar.component(.day, from: recycling.first!.date), 1)
        XCTAssertEqual(calendar.component(.day, from: recycling.last!.date), 31)
    }

    func test_collectionCalendar_doesNotInventDatesForUnknownZones() {
        XCTAssertTrue(FindCollectionScheduleUseCase.collectionDates2026(day: "Tuesday", area: "Area 3").isEmpty)
        XCTAssertTrue(FindCollectionScheduleUseCase.collectionDates2026(day: "Saturday", area: "Area 1").isEmpty)
        XCTAssertTrue(FindCollectionScheduleUseCase.collectionDates2026(day: nil, area: nil).isEmpty)
    }

    func test_findCollectionSchedule_addsCouncilCalendarDatesToLiveZone() async throws {
        let repository = MockWasteWiseRepository()
        repository.schedule = CollectionSchedule(address: address, collections: [], collectionDay: "Tuesday", recyclingArea: "Area 2")
        let result = try await FindCollectionScheduleUseCase(repository: repository).execute(address: address)
        XCTAssertFalse(result.collections.isEmpty)
        XCTAssertEqual(result.address, address)
        XCTAssertEqual(result.recyclingArea, "Area 2")
    }


    func test_collectionLookup_populatesCalendarFromPersistedAddress() async {
        let suite = "WasteWiseTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let original = ResidentAddressStore(defaults: defaults, autocomplete: MockAddressAutocomplete())
        original.save(address)
        let reopened = ResidentAddressStore(defaults: defaults, autocomplete: MockAddressAutocomplete())
        XCTAssertTrue(reopened.hasSavedAddress)
        XCTAssertEqual(reopened.addressRevision, 0)
        let repository = MockWasteWiseRepository()
        repository.schedule = CollectionSchedule(address: address, collections: [], collectionDay: "Tuesday", recyclingArea: "Area 2")
        let viewModel = CollectionScheduleViewModel(repository: repository)
        let loaded = expectation(description: "Saved address produces calendar dates")
        let subscription = viewModel.$result.compactMap { $0 }.sink { _ in loaded.fulfill() }
        viewModel.findCollectionDates(address: reopened.address)
        await fulfillment(of: [loaded], timeout: 5)
        XCTAssertEqual(repository.requestedAddress, address)
        XCTAssertFalse(viewModel.result?.collections.isEmpty ?? true)
        subscription.cancel()
    }

}
