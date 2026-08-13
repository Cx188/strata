# Strata Launcher

This is the official public distribution repository for Strata. It contains
player downloads, installation helpers, and player-facing release notes. Live
launcher news is served by `api.stratamc.net`; the launcher source
code is maintained in a separate private repository.

## Download

[Download the latest Strata release](https://github.com/Cx188/strata/releases/latest).

Each player-facing release contains exactly three installers:

| Platform     | File                                     |
| ------------ | ---------------------------------------- |
| Windows      | `Strata-Windows-Setup-<version>.exe`     |
| macOS        | `Strata-macOS-Universal-<version>.dmg`   |
| Linux x86_64 | `Strata-Linux-x86_64-<version>.AppImage` |

## Install from a terminal

### Windows PowerShell

```powershell
irm https://raw.githubusercontent.com/Cx188/strata/main/install.ps1 | iex
```

The script asks where to install Strata, creates a desktop shortcut, and starts
the launcher.

### Linux

```sh
curl -fsSL https://raw.githubusercontent.com/Cx188/strata/main/install.sh | sh
```

The script installs the latest AppImage, creates menu and desktop shortcuts
when supported, and starts Strata.

### macOS

Download the DMG from the
[latest release](https://github.com/Cx188/strata/releases/latest),
open it, and drag Strata into Applications.

## Automatic updates

Strata checks for updates when it starts. Technical update manifests,
differential blockmaps, and updater-only packages live in the separate
[`Cx188/strata-updates`](https://github.com/Cx188/strata-updates)
repository so this download page stays simple.

## Safety

Only install Strata from this repository or <https://stratamc.net>. The command
installers verify the selected GitHub release asset with SHA-256 before running
or installing it.

Releases are published through a manually approved environment, are immutable after publication, and include GitHub build attestations. You can verify a downloaded installer with GitHub CLI:

```sh
gh attestation verify ./Strata-PLATFORM-VERSION -R Cx188/strata
```

Replace the example path with the installer you downloaded.

Current packages are not code-signed, so Windows SmartScreen, antivirus tools,
or macOS Gatekeeper may warn. Do not bypass a warning for a file obtained from
any other source.

Strata is independent and is not affiliated with Mojang Studios or Microsoft.
