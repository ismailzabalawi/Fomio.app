# Duo windows + notifications merge — 2026-10-22

Branch `claude/duo-notifications-merge`, merging `duo-adaptive-reading` (`b92b29d`) into `main` (`27db168`). Not pushed or uploaded.

## What changed

- Notification inbox, device alert setup and duplicate-tap filtering moved into `AppWindows`; see [architecture](../../architecture.md#notifications-with-several-windows--2026-10-22).
- Taps go to the most recently used window (key or active), and are held until a window finishes launching.
- A rejected key on a tap now expires every window; only the tapped window asks to sign in.
- Duo's feed geometry and image loader replace main's equivalents. Main's behind-the-bar geometry test is kept against Duo's model.
- Two uncommitted Duo search-field edits are carried as their own commit (`e4e621f`).

## Tests added

`FomioTests/MultiWindowNotificationTests.swift` (9 unit tests) and `FomioUITests/MultiWindowNotificationUITests.swift` (3 iPad UI tests, which skip unless both windows are on screen together).

## Results

Pending. When this record was written, the host had no room to boot a dedicated simulator: other sessions had 9 simulators booted and several test runs in progress. Builds (app, unit and UI test targets) succeed for the iOS Simulator.
