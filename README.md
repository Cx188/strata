# Strata V1 — retirement and cleanup

**Strata V1 is being retired as development moves to Strata V2.** This repository
remains available for V1 removal instructions and historical release information.
It is not the Strata V2 source or download repository.

Do not reinstall V1 expecting a supported, working update service. The public V1
updater feed is being retired. Some installed versions require that feed during
startup and can stop at the update screen once it becomes unavailable. CurseForge
and online launcher news also depend on the availability of the old Strata API.
Making a repository private does not remotely uninstall software or erase anyone's
local worlds, instances or account data.

## Before removing V1

1. Close Minecraft and the old Strata launcher.
2. Back up any worlds, screenshots, profiles or modpacks you want to keep. The
   default Windows instance folder is `%APPDATA%\strata\instances`; users who
   selected a custom instance location should back up that location instead.
3. Use the same Windows account you used for V1. Do not run the cleanup under
   another person's administrator account.

**The normal V1 uninstaller preserves game data by default. Uninstalling the app
alone is not a complete data wipe. The optional cleanup script below permanently
deletes the verified V1 data it lists. There is no undo or automatic V2 migration.**

## Windows: uninstall V1 and wipe its data

### Option A: download and review the PowerShell script

Save [Uninstall-Strata-V1.ps1](https://raw.githubusercontent.com/Cx188/strata/main/Uninstall-Strata-V1.ps1)
in your Downloads folder, keeping the `.ps1` extension. Open PowerShell and preview
the exact removal targets first:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\Downloads\Uninstall-Strata-V1.ps1" -Preview
```

If those targets are correct and your backups are ready, run:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "$env:USERPROFILE\Downloads\Uninstall-Strata-V1.ps1"
```

Type **`WIPE V1`** when prompted to confirm the uninstall and permanent deletion.
If Downloads was moved or the file was saved elsewhere, replace the example
script path with the actual saved filename. `ExecutionPolicy Bypass` applies to
that one PowerShell process; it does not change the system-wide execution policy.

### Option B: copy and paste

Open [COPY-PASTE-UNINSTALL.txt](COPY-PASTE-UNINSTALL.txt), review it, and paste the
**entire block** into PowerShell. It is the same cleanup script, wrapped as a
single paste-ready command, and also requires **`WIPE V1`** before deletion.

### What the cleanup does

- Finds the registered V1 uninstaller from Windows, rather than assuming a
  username, drive or installation directory. It checks the V1 registration and
  executable metadata before running it.
- Runs that uninstaller, then removes the verified V1 launcher data at
  `%APPDATA%\strata` and updater cache at `%LOCALAPPDATA%\strata-updater`.
- Includes V1's local worlds, screenshots, installed instances/modpacks, saved
  account tokens, settings and cached runtimes in the data wipe.
- For a custom instance location, removes only individually verified V1 instance
  directories with matching metadata. It never wipes the whole custom parent
  directory simply because it appears in a setting.
- Preserves Strata V2, the separately named `strataV1` edition, normal `.minecraft`
  data and unrelated directories. It refuses ambiguous or linked/junction parent
  paths instead of following them into other data.
- Refuses to wipe data while it detects a V1 Minecraft process still running.
  Unverified custom directories are explicitly reported as preserved/partial.

The helper supports Windows PowerShell 5.1 and PowerShell 7. Data cleanup is for
the current Windows account only, not every account on the PC. An all-users app
installation can require administrator permission to uninstall; do not bypass
Windows permission or security warnings. If a registration or path cannot be
verified, read the error and use the manual route rather than deleting guessed
directories. Already-uninstalled V1 data can still be cleaned when its V1 config
is recognizable. Arbitrary portable/orphaned app locations are not guessed.

### Manual Windows alternative

1. Open **Settings → Apps → Installed apps** and uninstall **Strata 1.x**. Be sure
   it is the old V1 application, not V2.
2. After backing up your files, open `%APPDATA%\strata` and delete that V1 folder.
3. Remove `%LOCALAPPDATA%\strata-updater` if it exists.
4. If you configured custom instance storage, remove only your V1 instance
   directories there. Do not delete a shared games folder or unrelated files.

Do **not** delete `%LOCALAPPDATA%\Strata`, `com.strata.launcher`, a V2 data directory
or normal `.minecraft` data as part of V1 cleanup. If you are unsure which folder
belongs to which app, stop and ask for help before deleting anything.

## macOS and Linux

The PowerShell helper is **Windows-only**. Do not apply its commands or assume
its data paths apply on macOS/Linux. Back up your worlds, remove the V1 app using
the installation method you used, and confirm the V1-specific data paths before
removing them. This cleanup change does not provide or qualify an automatic
macOS/Linux data-wipe script, and should not be used to wipe shared Minecraft or
V2 folders.

## Historical releases and support

[Existing V1 releases](https://github.com/Cx188/strata/releases) are historical
downloads, not a recommendation to install V1 now. No new V1 installer release is
created by this documentation/cleanup update. Old terminal installation helpers
are retained for history; they are not the V2 installation method.

- [Ready-to-send Windows cleanup instructions](V1-Uninstall-Announcement.txt)
- [Strata Discord](https://discord.gg/bK47FB2sNw)

The cleanup helper has parser and disposable-fixture tests for its deletion
allowlist, read-only/hidden files, junction handling and path refusal. Those tests
do not uninstall real user applications or claim every PC configuration has been
tested. They can be run locally with:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\uninstall-windows.test.ps1
```

Strata is independent and is not affiliated with Mojang Studios or Microsoft.
