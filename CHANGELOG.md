# Changelog

All notable changes to this project will be documented in this file.

## [Unreleased]
- *work in progress*

## [1.1.0] - 2025-12-24
### Added
- **Auto-Updater**: The script now checks for updates automatically on startup.
- **Branch Safety**: Warning system for developers working on the `dev` branch.

### Fixed
- **GCC Symbols Fix**: Added `ITM_deregisterTMCloneTable` and `ITM_registerTMCloneTable` to the whitelist to prevent false positives on Linux systems.
- Improved binary detection path.

## [1.0.0] - 2025-12-21
### Added
- Initial release of the Push_swap Tester.
- Input validation checks (duplicates, non-numeric, max integer).
- Identity test (already sorted lists).
- Random permutations test (3, 5, 100, 500 numbers).
- Integrated `checker` verification.