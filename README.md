# devclean

A professional terminal tool for auditing and safely cleaning
developer-related disk usage on macOS. Built for Flutter/iOS/Android
developers juggling Xcode, Simulators, Gradle, CocoaPods, Node, and
Firebase caches that quietly eat tens of gigabytes.

## Purpose

Developer tooling on macOS accumulates disk usage fast: Xcode DerivedData,
old Simulator devices, iOS DeviceSupport files, Gradle/CocoaPods/npm
caches, Docker images, Homebrew downloads. `devclean` audits all of it in
one place and lets you reclaim space **safely, deliberately, and with full
visibility into what will happen before it happens.**

## Safety model

devclean is built around one rule: **nothing is ever deleted without an
explicit confirmation**, and dry-run mode can prove it.

- **Read-only by default.** `devclean scan`, `devclean doctor`, and
  `devclean report` never modify anything.
- **Every destructive action explains itself first**: target path or
  command, current size, what will be lost, whether it can be recreated,
  and the exact action about to run.
- **Two confirmation tiers:**
  - Low-risk, fully recreatable caches (Xcode DerivedData, CocoaPods
    cache, Flutter pub-cache, npm/yarn cache, Homebrew cache) ask a plain
    `y/N`.
  - High-impact actions - Simulator deletion, iOS DeviceSupport removal,
    Xcode Archive removal, Docker pruning, AVD deletion, project build
    folder deletion - require typing `DELETE` in full.
- **Global `--dry-run`** works for every command and the interactive menu.
  It never deletes anything; it prints exactly what would run and
  estimates space that would be reclaimed.
- **Confined to your home directory.** The internal path-safety guard
  (`is_dangerous_path`) refuses to operate on empty paths, `/`, `$HOME`
  itself, or anything outside `$HOME`. It also refuses common system
  directories outright.
- **No sudo, ever**, for normal operation.
- **WhatsApp data is never touched.** devclean only measures and, on
  request, reveals the folder in Finder.

## Installation

```sh
cd ~/Tools/devclean
./install.sh
```

`install.sh`:

1. Makes the executables runnable.
2. Creates `logs/` and `reports/` if missing.
3. Tries to symlink `devclean` onto your `PATH` at `/opt/homebrew/bin`
   (Apple Silicon) or `/usr/local/bin` - only if writable without `sudo`,
   and only after you confirm.
4. If neither location is writable, it offers to add a single, clearly
   marked alias line to `~/.zshrc`, after backing up your existing
   `~/.zshrc`. It will never add the alias twice.

Nothing is installed silently - every step prints what it did.

### Uninstalling

```sh
./uninstall.sh
```

Removes only the symlink or alias this installer created. It never
deletes `logs/`, `reports/`, or the source directory unless you pass
`--purge-logs` / `--purge-reports`, and even then it asks first.

## Commands

```
devclean            Open the interactive menu
devclean scan        Scan known developer locations and print a summary
devclean clean        Open the interactive safe-clean menu
devclean doctor       Check the health of your development environment
devclean report       Generate a timestamped TXT and JSON report
devclean --dry-run    Combine with any command; never deletes anything
devclean --help
devclean --version
```

### Interactive menu

```
devclean
```

```
DEV CLEAN v1.0.0

Disk free: 56 GB
Potentially recoverable: 28 GB

  1) Scan system
  2) Quick clean
  3) Xcode cleanup
  4) Simulator cleanup
  5) Android / Gradle cleanup
  6) Flutter cleanup
  7) Node cleanup
  8) Docker cleanup
  9) WhatsApp storage audit
 10) Developer doctor
 11) Generate report
  0) Exit
```

## Dry-run examples

```sh
devclean --dry-run scan
devclean --dry-run clean
devclean --dry-run doctor
```

In dry-run mode every destructive helper (`run_or_dry`, `safe_remove_path`)
prints `[DRY-RUN] ...` instead of executing, and still logs what it would
have done to `logs/`.

## What each cleaner removes

| Module      | Removes (after confirmation)                                            | Confirmation |
|-------------|---------------------------------------------------------------------------|--------------|
| Xcode       | DerivedData                                                                | y/N |
| Xcode       | iOS DeviceSupport versions you select                                      | DELETE |
| Xcode       | Archives you select                                                        | DELETE |
| Simulator   | Unavailable / selected devices (`simctl delete`)                          | DELETE |
| Simulator   | Erase content & settings on selected devices (`simctl erase`)             | DELETE |
| Android     | Selected AVDs                                                              | DELETE |
| Android     | `build`/`.gradle` inside a project path you type                          | DELETE |
| Gradle      | `~/.gradle/caches`, `~/.gradle/wrapper`                                    | y/N |
| Flutter     | `~/.pub-cache`                                                             | y/N |
| Flutter     | `.dart_tool`/`build` inside a project path you type                       | DELETE |
| CocoaPods   | `~/Library/Caches/CocoaPods`                                               | y/N |
| CocoaPods   | `Pods/` inside a project path you type                                    | DELETE |
| Node        | npm/yarn cache, pnpm store (via each tool's native cache command)         | y/N |
| Docker      | Containers/images/volumes/build cache (`docker ... prune`)                | DELETE |
| Homebrew    | `brew cleanup` (previewed first with `brew cleanup -n`)                   | y/N |

**Quick clean** bundles only the y/N-tier items above (Xcode DerivedData,
CocoaPods cache, Flutter pub-cache, npm/yarn cache, Homebrew cache) plus
devclean's own logs older than a configurable threshold (default 30 days,
`DEVCLEAN_LOG_RETENTION_DAYS`).

## What it never removes

- The Android SDK install itself (report only)
- `node_modules` anywhere, ever, automatically
- Project source code, `.dart_tool`/`build`/`Pods`/Android `build` folders
  outside a project path you explicitly typed
- Credentials, SSH keys, signing certificates, provisioning profiles,
  Firebase config files, `.env` files
- Databases of any kind
- WhatsApp message/media data (audit only - see below)
- Anything outside `$HOME` (enforced by `is_dangerous_path`)

## Simulator workflow

`devclean` (menu) -> `4) Simulator cleanup`, or `devclean clean` ->
`3) Simulator cleanup`:

```
  1) List devices              (name, runtime, state, UUID, size)
  2) Delete unavailable devices (xcrun simctl delete unavailable)
  3) Delete selected devices    (xcrun simctl delete <UUID>)
  4) Erase selected devices     (xcrun simctl erase <UUID> - keeps device)
  5) Shut down all booted simulators
```

A booted simulator is never deleted or erased - shut it down first.
DELETE and ERASE are always presented and confirmed separately, since one
removes the device and the other only wipes its content.

## WhatsApp warning

devclean audits `~/Library/Group Containers/group.net.whatsapp.WhatsApp.shared`
(Message / Media / Logs sizes) and can open it in Finder. **It never
deletes anything there and never will.** There is no reliable way for a
generic tool to know what WhatsApp data is safe to lose - back up chats
from within WhatsApp itself before manually removing anything.

## Troubleshooting

- **"missing module" error on startup** - the install directory moved or a
  `lib/*.sh` file was deleted; re-clone or restore the file.
- **Colors look wrong / no colors** - devclean disables color automatically
  when stdout isn't a TTY, or when `NO_COLOR` is set. Unset `NO_COLOR` to
  re-enable.
- **`devclean: command not found` after installing** - open a new
  terminal, or `source ~/.zshrc` if `install.sh` fell back to the alias
  path. Check `install.sh`'s summary output for exactly what it did.
- **Docker section says daemon not reachable** - Docker Desktop isn't
  running; devclean detects this instead of hanging indefinitely.
- **Simulator list looks empty** - `xcrun simctl` requires the Xcode
  command line tools; `devclean doctor` reports whether they're set up.

## Logs and reports

- Session logs: `logs/devclean-YYYYMMDD-HHMMSS.log` (paths examined,
  actions approved/skipped, bytes before/after, errors - never file
  contents).
- Reports: `reports/devclean-report-YYYYMMDD-HHMMSS.{txt,json}` via
  `devclean report`.

## Examples

```sh
devclean                    # interactive menu
devclean scan                # read-only summary
devclean --dry-run clean      # preview every cleanup category, delete nothing
devclean doctor               # environment health check
devclean report               # write a TXT + JSON report to reports/
```

## Tests

```sh
bash tests/smoke_test.sh
bash tests/test_utils.sh
```

## License

MIT - see [LICENSE](LICENSE).
