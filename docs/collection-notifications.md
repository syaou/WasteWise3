# Collection reminder notification extension

This branch adds a second embedded iOS extension alongside `ReminderExtension` (the widget).
It does not add Core Data or change the collection lookup/calendar/widget behavior.

## Data and identifiers

- Saved household: existing `ResidentAddressStore` / `ResidentialAddress`.
- Council metadata: `CollectionSchedule.collectionDay` and `.recyclingArea`, populated from ArcGIS `DAY` and `WEEK`.
- Reminder scheduling does **not** use `.collections`, the calendar's derived dates, a pickup timestamp, or a bin stream.
- Main app: `com.WasteWise.sana.Wastewise`.
- Content extension: `com.WasteWise.sana.Wastewise.CollectionNotificationContent`.
- Extension point: `com.apple.usernotifications.content-extension`.
- Category, registered by the app and matched in the extension plist: `WASTEWISE_USUAL_COLLECTION`.
- Stable request IDs: `wastewise.collection.weekly` and `wastewise.collection.sample`.
- Existing App Group `group.com.WasteWise.sana.Wastewise` and widget storage are unchanged. The content extension receives only weekday, area, payload version and optional sample flag; it needs no address access or App Group entitlement.

`CollectionReminderController` persists opt-in, Sydney hour/minute and address-associated council metadata in app-local UserDefaults. It uses a repeating `UNCalendarNotificationTrigger` with weekday/hour/minute in `Australia/Sydney`. The trigger weekday is the selected number of days before the usual collection weekday, wrapping across week boundaries. The default is 6:00 pm Sydney time; existing saved reminder times migrate to 6:00 pm once when the updated app opens. Residents can use **Set reminder to put bins out** to choose collection day or 1–6 days before it and a Sydney time. Choices apply only on **Save reminder**; Cancel leaves the existing reminder unchanged. This is not an assertion that a pickup will occur. A resident's saved schedule survives app relaunches; changing/removing the address immediately invalidates its reminder while a new lookup is pending.

The controller serializes notification-center writes and checks revisions after asynchronous work. A late permission response or add cannot restore a reminder after it is disabled or its address is removed. Changes clear pending and delivered weekly/sample notifications. Foreground permission checks preserve delivered notifications and pending samples unless authorization has been revoked.

The custom UIKit extension shows the usual weekday, recycling area, explanatory copy and the existing empty-bin mascot (its countdown numeral is excluded). It supports Dynamic Type and falls back to readable text if the image/payload is unavailable. No network request is needed to expand a notification.

## Test on iPhone Simulator

1. Open `Wastewise.xcodeproj`, select the **Wastewise** scheme, **Debug**, and **iPhone 17 Pro — iOS 26.5**, then Run. Run the app scheme so both `.appex` bundles are embedded.
2. On **Home**, save a supported Parramatta address if needed. Wait for **Usual collection day** and **Recycling area** in the Collection reminder card.
3. Tap **Set reminder to put bins out**, choose a day and time, tap **Save reminder**, and choose **Allow** at the notification prompt. If previously denied, use **Open notification settings**, allow notifications, return and save the reminder again.
4. Open the reminder button again to edit the day and time. Cancel should leave the saved schedule unchanged. The default is 6:00 pm Sydney time on the day before the displayed usual collection weekday.
5. In Debug only, tap **Send sample in 10 seconds**. Go Home (`Command-Shift-H`); optionally use **Device > Lock**. Wait ten seconds.
6. Press and hold the delivered notification to expand it. Expect a custom **WasteWise** heading, mascot, **Development sample**, **Usual collection day** with the weekday, recycling area and the council-information caveat. A short tap opens the app instead of expanding it.
7. Return to Home, schedule another sample, and save a different reminder time before ten seconds. The sample should not arrive; the weekly reminder is replaced at the new time. Send another sample to inspect the view again.
8. Schedule a sample, then tap **Turn off reminder** before ten seconds. Neither the sample nor future weekly reminders should fire. Already delivered collection reminders are removed too.
9. Change the saved address: the old reminder is cancelled immediately, and a new one is scheduled only when the new address returns valid weekday/area information. Removing the address cancels reminders and turns the setting off. Do not remove a real saved address just for testing unless you intend to restore it.
10. The sample button and scheduling code are excluded from Release builds. The usual weekly reminder and content extension remain available.

Notification permission, Focus and notification-summary settings can affect presentation. The notification must have the matching category to use the custom content extension; no remote push server or APNs entitlement is required for these local reminders.

## Automated checks

Run the Wastewise scheme's tests. `CollectionReminderTests` covers opt-in-only permission requests, payload/category and weekly timezone components, persistence, time/weekday/address replacement, stale address rejection, pending and delivered cancellation, permission denial/revocation, delayed permission/add races, sample cancellation, foreground sample preservation, invalid metadata and scheduling failures. Existing collection and widget tests are retained.

The target follows Apple's [notification content extension contract](https://developer.apple.com/documentation/usernotificationsui/unnotificationcontentextension). `NotificationViewController.didReceive` logs `Custom WasteWise notification content received and displayed` under the content extension bundle identifier, useful for confirming that the system instantiated the custom view.
