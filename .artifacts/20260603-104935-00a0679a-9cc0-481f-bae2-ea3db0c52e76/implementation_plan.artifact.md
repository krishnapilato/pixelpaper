# Fix App State Problems and Optimizations

This plan addresses several identified issues in the `AppState` management, theme synchronization, and initial loading experience.

## Proposed Changes

### [State Management] lib/app_state.dart

#### [app_state.dart](file:///C:/Users/krish/OneDrive/Documents/GitHub/pixel-paper/lib/app_state.dart)

- **Concurrency Fix**: Introduce a `_needsReload` flag in `loadData`. If `loadData` is called while `isLoading` is true, it sets `_needsReload = true`. At the end of `loadData`, if `_needsReload` is true, it triggers another reload.
- **`renamePdf` Bug**: Fix the order preservation for `pinnedPdfs` and `selectedPdfs` by using `indexWhere` and replacing the element at that specific index instead of appending it to the end.
- **Caching**: Cache the result of `activeDirectory` in a private variable `_activeDirPath` to avoid frequent async calls to `path_provider`.
- **Initialization**: Wrap `_initPrefsAndData` in a `try-finally` block to ensure `isInitialLoading` is set to `false` and `notifyListeners()` is called even if an error occurs.
- **Naming**: Use `microsecondsSinceEpoch` for new image filenames to further reduce collision probability.
- **Redundancy**: Remove the redundant `notifyListeners()` call in `saveImage` before calling `loadData`.

```dart
// Example of the concurrency fix in loadData
bool _needsReload = false;

Future<void> loadData() async {
  if (isLoading) {
    _needsReload = true;
    return;
  }
  isLoading = true;
  _needsReload = false;
  notifyListeners();

  try {
    // ... logic ...
  } finally {
    isLoading = false;
    notifyListeners();
    if (_needsReload) {
      loadData();
    }
  }
}
```

---

### [Theme & UI] lib/main.dart & lib/main_screen.dart

#### [main.dart](file:///C:/Users/krish/OneDrive/Documents/GitHub/pixel-paper/lib/main.dart)

- Update `MaterialApp` to use `app.seedColor` instead of hardcoded `Colors.blue`.

```dart
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: app.seedColor,
        // ...
```

#### [main_screen.dart](file:///C:/Users/krish/OneDrive/Documents/GitHub/pixel-paper/lib/main_screen.dart)

- Add a loading overlay check for `app.isInitialLoading` to prevent showing an empty/broken UI before the initial data is ready.

---

## Verification Plan

### Automated Tests
- No new automated tests are proposed as this is a fix for existing logic, but I will verify via manual testing.

### Manual Verification
- **Race Condition**: Rapidly trigger file operations (like saving or renaming) and verify that the UI always updates to the final state.
- **Pin Order**: Pin a PDF, rename it, and verify its position in the pinned list (if sorted by pin) or that it remains pinned.
- **Theme Color**: Change the theme color in settings and verify that the entire app's color scheme updates (requires checking `settings_modal.dart` to see if it allows changing color - it seems it doesn't have a UI for it yet, but the state supports it).
- **Initial Load**: Simulate a slow load (e.g., adding a delay in `loadData`) and verify that a loading indicator or at least a blank screen with a spinner (if implemented) is shown instead of a broken UI.
