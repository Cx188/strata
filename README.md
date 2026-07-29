# Strata Launcher

This is the official public distribution repository for Strata. It contains
player downloads, installation helpers, launcher news, and the curated
extension catalog. The launcher source code is maintained in a separate private
repository.

## Download

[Download the latest Strata release](https://github.com/ProjectStrata/launcher/releases/latest).

Each player-facing release contains exactly three installers:

| Platform     | File                                     |
| ------------ | ---------------------------------------- |
| Windows      | `Strata-Windows-Setup-<version>.exe`     |
| macOS        | `Strata-macOS-Universal-<version>.dmg`   |
| Linux x86_64 | `Strata-Linux-x86_64-<version>.AppImage` |

## Install from a terminal

### Windows PowerShell

```powershell
irm https://raw.githubusercontent.com/ProjectStrata/launcher/main/install.ps1 | iex
```

The script asks where to install Strata, creates a desktop shortcut, and starts
the launcher.

### Linux

```sh
curl -fsSL https://raw.githubusercontent.com/ProjectStrata/launcher/main/install.sh | sh
```

The script installs the latest AppImage, creates menu and desktop shortcuts
when supported, and starts Strata.

### macOS

Download the DMG from the
[latest release](https://github.com/ProjectStrata/launcher/releases/latest),
open it, and drag Strata into Applications.

## Automatic updates

Strata checks for updates when it starts. Technical update manifests,
differential blockmaps, and updater-only packages live in the separate
[`ProjectStrata/launcher-updates`](https://github.com/ProjectStrata/launcher-updates)
repository so this download page stays simple.

## Safety

Only install Strata from this repository. Strata is not affiliated with Mojang
Studios or Microsoft.
