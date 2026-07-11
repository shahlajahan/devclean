# Changelog

## v1.1.0

### Added
- Multi-select cleanup: pick several categories at once from `devclean clean`,
  confirm once, and run them in sequence (each category keeps its own
  existing confirmations).
- Markdown report output alongside TXT/JSON (`devclean report`).
- ASCII progress indicator during `devclean scan`.
- Bun support: detection, version, cache size, scan, doctor, and cache
  cleanup (`bun pm cache rm`).
- pnpm version detection, shown in `devclean scan` and `devclean doctor`.
- Doctor now checks yarn, pnpm, and Bun (previously only Node/npm).
- Doctor health score: a 0-100 score plus a short recommendations list,
  printed at the end of `devclean doctor`.
- `devclean update`: checks the latest GitHub release for this project and
  reports the current version, latest version, release URL, and whether
  an update is available. Read-only - it never downloads or installs
  anything.
- `devclean scan` now prints "Top Space Consumers" (the 5 largest measured
  items) and a safe/risky/total cleanup breakdown.

### Changed
- Doctor's `MISSING` status is now `ERROR`, matching the documented
  OK/WARNING/ERROR/OPTIONAL tiers (four tiers, not five - no new severity
  level was introduced).
- The "estimated reclaimable" figure (menu header and `scan` summary) now
  also includes Simulator device data and Android AVD sizes, which v1.0.0
  never counted. The number is larger/more accurate as a result; this is
  intentional, not a regression.

### Notes
- No existing command, menu number, or confirmation requirement changed
  meaning. Every new destructive action (Bun cache cleanup) uses the same
  `run_or_dry`/`confirm_yes_no` machinery as every v1.0.0 cleaner, so it
  inherits `--dry-run` and dangerous-path rejection automatically.

## v1.0.0 - Initial Release

### Added
- Interactive cleanup menu
- Developer environment doctor
- Disk usage scanner
- Report generator (TXT + JSON)
- Safe cache cleanup
- Dry-run support
- Xcode cleanup
- Simulator management
- Flutter cleanup
- Android / Gradle cleanup
- Node cleanup
- CocoaPods cleanup
- Homebrew cleanup
- WhatsApp storage audit

### Security
- No sudo required
- All destructive actions require confirmation
- High-impact actions require typing DELETE
- Dangerous paths are rejected
- Dry-run never deletes files