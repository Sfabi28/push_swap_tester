# Changelog

All notable changes to this project will be documented in this file.

## [1.2.0] - 2026-01-08
### Added
- **CHANGELOG.md**: trace changes of the project
- **Auto-Cleaner**: Added auto cleaning at the end of the tester

### Fixed
- Fixed a bug that cause errors happening in "error managment" not being saved in the log file.

## [1.1.0] - 2025-12-24
### Added
- **Auto-Updater**: The script now checks for updates automatically on startup.
- **Developer Mode**: Added a warning when running the tester from a non-main branch.
- **Library Check**: Improved forbidden function detection by analyzing internal library symbols to avoid false positives.

### Fixed
- Fixed compilation logic when testing single functions inside the static library.

## [1.0.0] - 2025-12-22
### Added
- Initial release of the push_swap Tester.
- Checks for input errors
- Multiple checks on many number of arguments.
- Norminette check integration.
- Leaks check
- Avarage of the tests saved