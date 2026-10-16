# Personal Finance — Flutter refactor

This folder contains a refactored `lib/` implementation for the existing Flutter app package `financer`, plus a `pubspec.yaml` dependency reference.

## Install / integrate

1. Copy the `lib/` directory into the root of your Flutter project, replacing the corresponding old source files.
2. Merge the dependencies from `pubspec.yaml` into your existing `pubspec.yaml` (keep your app's existing metadata and other dependencies).
3. Run `flutter pub get`, then `dart format lib` and `flutter analyze`. This code uses Flutter 3.27+ APIs and a Dart 3.6+ language baseline.
4. Run the app normally with `flutter run`.

Imports use `package:financer/...`; change the package name if your project's `name:` is different.

## Implemented

- Editable quick-expense presets; tapping one logs a timestamped expense immediately.
- Transaction `dateLogged` stamps with date and time in history and PDF.
- Fixed costs and investment allocations in one section. Each line can be a fixed amount or a percentage of starting wealth / starting wealth plus income.
- A surplus buffer uses `total resources - projected expenses`, where each planned category is reserved at the higher of planned or actual spending; unplanned expenses therefore reduce the buffer.
- Income entries increase resources. Settled debts subtract from resources; settled loans collected add to resources. Reopening or deleting an item reverses that effect automatically.
- SharedPreferences persistence for all models and migration from the original `budget_state_v1` snapshot.
- Material 3 theme controller (system/light/dark), animated indicators, allocation distribution ring, reset confirmation, and PDF share/save flow.

## Accounting semantics

`wealth` is the starting amount entered by the user. Income entries are additive. Settled debts and collected loans alter available resources only once through the ledger status; do not also log the same settlement as an expense/income transaction unless you intend to record a second cash movement. `actualRemaining` subtracts logged expenses from total resources. `unplannedSurplus` subtracts each category's higher planned/actual spending from total resources.

## PDF export

The PDF button generates a report and opens the platform share/print interface. The available destination options (including saving to a file) depend on the target platform.

## Validation note

Flutter SDK was not available in the build container, so `flutter analyze` / device builds could not be executed here. Run the install steps above in your Flutter environment and resolve any SDK-specific warnings before release.
