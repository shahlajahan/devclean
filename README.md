
# devclean

> Safe macOS cleanup for Flutter, iOS, Android and Node.js developers.

---

## Quick Clean Preview

![Quick Clean](assets/screenshots/quick-clean.png)
> Safe macOS cleanup for Flutter, iOS, Android and Node.js developers.

`devclean` is a professional command-line tool that audits developer-related
disk usage on macOS and safely removes recreatable caches with explicit
confirmation.

Unlike generic cleanup tools, **devclean understands developer environments**
including Xcode, iOS Simulators, Flutter, Gradle, CocoaPods, Node.js,
Homebrew and Docker.

---

## ✨ Features

## Scan

devclean scans your complete development environment and estimates reclaimable storage.

![Scan](assets/screenshots/scan.png)

- Audit developer disk usage
-  Diagnose development environment (`doctor`)
-  Safe cache cleanup
-  Global `--dry-run` mode
-  TXT & JSON reports
-  Xcode cleanup
-  iOS Simulator cleanup
-  Flutter & Dart cleanup
-  Android & Gradle cleanup
-  Node / npm cleanup
-  Homebrew cleanup
-  Docker cleanup
-  WhatsApp storage audit (read-only)

---

## Why devclean?

A macOS developer machine slowly fills with:

- Xcode DerivedData
- Simulator devices
- iOS DeviceSupport
- Gradle caches
- CocoaPods caches
- Flutter pub-cache
- npm/yarn caches
- Docker images
- Homebrew downloads

Finding these manually is tedious.

**devclean scans them all in one place** and shows exactly what is safe to
remove before anything happens.

---

# Safety First

Safety is the primary design goal.

devclean **never deletes anything automatically.**

Every cleanup operation is explained before execution and always requires
confirmation.

There are two confirmation levels:

| Operation | Confirmation |
|-----------|--------------|
| Safe caches | `y/N` |
| High-impact operations | Type `DELETE` |

Examples of high-impact operations:

- Simulator deletion
- DeviceSupport removal
- Docker prune
- Archive removal
- Project build folders

---

## Dry Run

Every cleanup command supports dry-run.

```bash
devclean --dry-run clean
```

Instead of deleting anything it prints:

```
[DRY-RUN] remove DerivedData
[DRY-RUN] npm cache clean
...
```

This allows you to verify exactly what will happen.

---

# Installation

Clone the repository:

```bash
git clone https://github.com/YOUR_USERNAME/devclean.git
cd devclean
```

Install:

```bash
./install.sh
```

Run:

```bash
devclean
```

---

# Commands

| Command | Description |
|----------|-------------|
| `devclean` | Interactive menu |
| `devclean scan` | Disk usage audit |
| `devclean clean` | Cleanup menu |
| `devclean doctor` | Environment diagnostics |
| `devclean report` | TXT + JSON reports |
| `devclean --dry-run` | Preview without deleting |


## Developer Doctor

Check your development environment in seconds.

![Doctor](assets/screenshots/doctor.png)

---

# What Can Be Cleaned?

| Component | Supported |
|------------|-----------|
| Xcode DerivedData | ✅ |
| DeviceSupport | ✅ |
| Simulators | ✅ |
| Flutter pub-cache | ✅ |
| Gradle cache | ✅ |
| CocoaPods cache | ✅ |
| npm cache | ✅ |
| Homebrew cache | ✅ |
| Docker | ✅ |

---

# What Will Never Be Removed

devclean intentionally refuses to touch:

- Source code
- Git repositories
- Credentials
- SSH keys
- Firebase configuration
- Provisioning profiles
- Signing certificates
- Databases
- `.env` files
- Anything outside your home directory
- WhatsApp messages or media

---

# WhatsApp

## WhatsApp Audit

Storage is analyzed safely without deleting anything.

![WhatsApp](assets/screenshots/whatsapp-audit.png)

devclean only audits WhatsApp storage.

It can:

- measure storage usage
- show Message / Media / Logs sizes
- open the folder in Finder

It **never deletes WhatsApp data.**

---

# Reports

Generate machine-readable reports:

```bash
devclean report
```

Outputs:

```
reports/
    devclean-report-20260711.txt
    devclean-report-20260711.json
```

---

# Testing

Run the test suite:

```bash
bash tests/test_utils.sh
bash tests/smoke_test.sh
```

---

# Requirements

- macOS
- Bash
- Xcode (optional)
- Flutter (optional)
- Android SDK (optional)
- Homebrew (recommended)

---

# Roadmap

## v1.1

- Interactive progress bars
- Disk usage history
- Faster scanning
- Brew package analysis
- Export HTML reports

## v1.2

- Plugin architecture
- CI support
- Automatic update checker

---

# Contributing

Contributions, bug reports and feature requests are welcome.

Please open an issue before submitting major changes.

---

# License

MIT License