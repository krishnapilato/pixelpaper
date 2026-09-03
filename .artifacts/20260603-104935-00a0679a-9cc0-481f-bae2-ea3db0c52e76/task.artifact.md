# Task Management

- [x] Fix App State Problems
	- [x] Update `AppState` in `lib/app_state.dart`
		- [x] Implement concurrency queue in `loadData`
		- [x] Fix pin/selection preservation in `renamePdf`
		- [x] Cache `activeDirectory`
		- [x] Improve `_initPrefsAndData` error handling
		- [x] Use `microsecondsSinceEpoch` for naming
		- [x] Remove redundant `notifyListeners()`
	- [x] Update `lib/main.dart` to use `app.seedColor`
	- [x] Update `lib/main_screen.dart` to handle `isInitialLoading`
- [x] Verify Fixes
	- [x] Verify concurrency handling (Logic reviewed)
	- [x] Verify pin order preservation (Logic reviewed)
	- [x] Verify theme color update (Logic reviewed)
	- [x] Verify loading state UI (Logic reviewed)
	- [x] Static analysis check
