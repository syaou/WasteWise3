# WasteWise

## Project overview

WasteWise is an iOS app that helps residents find information about household waste disposal and collection services.

## Domain context

The app is designed for **City of Parramatta residents** who need to identify the correct disposal method for household items, check collection dates and remember to put their bins out.

It currently supports:

- Saving a residential address with address autocomplete.
- Looking up collection information and displaying a 2026 collection calendar.
- Browsing and searching an offline waste disposal glossary.
- Configuring local collection reminders.
- Viewing a collection countdown widget.
- Preparing a simulated household clean-up booking.

## Architecture

WasteWise uses **MVVM with separate domain, use-case and data layers**.

The main parts are:

- **Views:** SwiftUI screens for Home, Collections, Check Item, Clean Up, address editing and reminder settings.
- **ViewModels:** Manage screen state, searches, results, errors and user actions. A shared address store keeps the resident’s address consistent across screens.
- **Use Cases:** `FindDisposalGuidanceUseCase`, `ClassifyWasteItemUseCase`, `FindCollectionScheduleUseCase` and `SubmitCleanupBookingUseCase` validate requests and coordinate waste guidance, collection lookups and simulated bookings.
- **Repositories and data:** The `WasteWiseRepository` protocol separates domain logic from data access. `LocalWasteWiseRepository` retrieves disposal guidance from Core Data, delegates collection lookups to the council’s live ArcGIS service and returns demonstration clean-up confirmations.

## Extensions

- **Reminder widget (`ReminderExtension`):** Uses WidgetKit to display a countdown to the next stored collection date, helping residents check upcoming collections from their Home Screen.
- **Notification content extension (`CollectionNotificationContent`):** Displays a custom expanded collection reminder with the usual collection weekday, recycling area and WasteWise mascot.

## Database

WasteWise uses **Core Data** to persist its offline disposal catalogue.

The database contains two related entities:

- `DisposalCategory`: The disposal route or category.
- `WasteItemRecord`: An item’s identifier, name, disposal instructions, council source URL and category relationship.

The glossary’s disposal-route filter queries the category relationship through the repository; its Use Case applies everyday-name matching and orders the results.

The database is populated from a bundled catalogue. New catalogue entries are added without duplicating existing records. It does not use CloudKit or provide cloud synchronisation.

The saved address and reminder preferences are stored separately in **UserDefaults**.

## App Group

App Group identifier: `group.com.WasteWise.sana.Wastewise`

The main app and Reminder widget use App Group UserDefaults to share collection dates. The app updates this data after a successful collection lookup and requests a widget refresh.

The resident’s address is not included in the shared widget data. The notification content extension receives its display information through the notification payload and does not require App Group access.

## Setup

1. Clone or download the repository.
2. Open `Wastewise.xcodeproj` in Xcode.
3. Select the **Wastewise** app scheme.
4. Choose an iOS simulator compatible with the project’s **iOS 26.5** deployment target.
5. Build and run the project.
6. Save a supported Parramatta address to load collection information.
7. Allow notifications when enabling reminders, and add the WasteWise widget to test the widget extension.

## Notes

- Use an Xcode installation with support for the configured iOS deployment target.
- Physical-device builds require appropriate signing and App Group provisioning for the app and widget.
- Address autocomplete and live collection lookups require internet access. The disposal catalogue works offline.
- Collection dates are generated using the **2026 council calendar**. Later years require an updated calendar implementation.
- Reminders use the **Australia/Sydney** time zone and the usual collection weekday; they do not confirm an individual pickup.
- Clean-up bookings are **demonstrations only** and are not submitted to council.
- Check Item provides text search and disposal guidance; camera-based item recognition is not implemented.
- The disposal glossary is a curated catalogue rather than the council’s complete live directory.
