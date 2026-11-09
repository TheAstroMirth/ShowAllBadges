<h1 align="center">ShowAllBadges</h1>

<p align="center">
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-GPL--3.0--or--later-5865F2?style=flat-square" alt="License"></a>
  <img src="https://img.shields.io/badge/Windows-10%20%2F%2011-5865F2?style=flat-square" alt="Windows 10/11">
  <img src="https://img.shields.io/badge/macOS-Apple%20Silicon%20%2F%20Intel-5865F2?style=flat-square" alt="macOS">
  <a href="https://github.com/Vendicated/Vencord"><img src="https://img.shields.io/badge/Vencord-supported-5865F2?style=flat-square" alt="Vencord"></a>
  <a href="https://github.com/Equicord/Equicord"><img src="https://img.shields.io/badge/Equicord-supported-5865F2?style=flat-square" alt="Equicord"></a>
</p>

A [Vencord](https://github.com/Vendicated/Vencord) / [Equicord](https://github.com/Equicord/Equicord) plugin that shows every badge on a Discord profile instead of hiding the extras behind a `+n` chip, with simple installers for **Windows and macOS**.

Created and maintained by [TheAstroMirth](https://github.com/TheAstroMirth).

> [!WARNING]
> **Unofficial third-party plugin.** It is not made, reviewed or supported by Discord, Vencord or Equicord. Client modifications are against Discord's Terms of Service. Use it at your own risk.

## Screenshots

_No screenshots yet._ Add a before/after picture of a profile here, for example `docs/before-after.png`.

## Features

- Shows all profile badges in the normal badge row. No `+3`, no extra click.
- Only changes how the list is displayed. It never adds, fakes or changes anyone's badges.
- No settings, no menus, one tiny patch.
- Installer and uninstaller for Windows and macOS.
- The installer finds your existing source folder, backs up any older copy of the plugin, builds, and tells you clearly whether it worked.
- Never downloads, clones or installs Vencord or Equicord for you. No administrator rights needed.

## Supported systems

| System | Status |
| --- | --- |
| Windows 10 / 11 | Supported (PowerShell 5.1 or newer, already included in Windows) |
| macOS, Apple Silicon and Intel | Supported (uses the built-in `bash`) |

## Vencord and Equicord compatibility

| Client | Plugin location |
| --- | --- |
| Vencord | `src/userplugins/showAllBadges/index.ts` |
| Equicord | `src/userplugins/showAllBadges/index.ts` |

Both are installed the same way.

Note for Equicord: recent Equicord sources also include a **Show All Badges** option under **Settings > Plugins > EquiTweaks**, and move a plugin named `ShowAllBadges` over to that option when Discord starts. If the plugin turns itself off after a restart, that is why. The EquiTweaks option does the same thing.

The patch was last checked against Discord stable build `668923` (10 November 2026), Vencord `1.15.16` and Equicord `1.15.16.0`. Discord changes its code often, see [Troubleshooting](#troubleshooting) if it stops working.

## Before you start

Custom plugins only work when Vencord or Equicord is **built from source**. The normal one-click installer version cannot load them. You need:

1. A source folder of Vencord or Equicord on your computer (a `git clone`, not a zip).
   - Vencord guide: <https://docs.vencord.dev/installing/> and <https://docs.vencord.dev/installing/custom-plugins/>
   - Equicord guide: <https://github.com/Equicord/Equicord#installing-equicord-devbuild>
2. [Git](https://git-scm.com/downloads), [Node.js LTS](https://nodejs.org/) and [pnpm](https://pnpm.io/installation) (`npm install -g pnpm`).

The installer checks all of this and explains what is missing. It will not install any of it for you.

## Installation

Download this repository from <https://github.com/TheAstroMirth/ShowAllBadges> (**Code > Download ZIP** and unzip it, or `git clone` it). Keep the folders together.

### Windows

1. Open `installers\windows`.
2. Double-click **`install.bat`**.
3. Follow the questions in the window.

### macOS

1. Open `installers/macos`.
2. Double-click **`install.command`**. The first time, macOS may block it: right-click the file, choose **Open**, then **Open** again.
3. Follow the questions in the Terminal window.

### What the installer does

1. Looks for an installed Vencord / Equicord.
2. Looks for your source folder. If it cannot find one, it explains why and lets you pick the folder yourself.
3. Checks the folder is a valid Git checkout and that Git, Node.js and pnpm are available.
4. Backs up any existing `src/userplugins/showAllBadges` before replacing it.
5. Copies the plugin and runs `pnpm build`.
6. Tells you whether Discord already uses this build, or how to apply it with the project's own `pnpm inject`.

Then restart Discord and turn on **ShowAllBadges** in **Settings > Plugins**.

### Manual install

Copy `plugin/index.ts` to `src/userplugins/showAllBadges/index.ts` in your Vencord source folder, then run:

```
pnpm build
pnpm inject
```

### Options

For scripted or repeated use:

| Windows (`install.ps1` / `uninstall.ps1`) | macOS (`install.sh` / `uninstall.sh`) | Meaning |
| --- | --- | --- |
| `-Source "C:\path"` | `--source "/path"` | Use this source folder, skip the search |
| `-Yes` | `--yes` | Do not ask questions, use the defaults |
| `-NoBuild` | `--no-build` | Do not run `pnpm build` |

## Uninstallation

- **Windows:** double-click `installers\windows\uninstall.bat`
- **macOS:** double-click `installers/macos/uninstall.command`

The uninstaller removes only the `src/userplugins/showAllBadges` folder and offers to rebuild. Your other plugins, your settings, and Vencord / Equicord / Discord themselves are left alone.

If the installer replaced an older copy of the plugin, the backup is kept in:

- Windows: `%LOCALAPPDATA%\ShowAllBadges\backups`
- macOS: `~/.showallbadges/backups`

To restore one, copy its `showAllBadges` folder back into `src/userplugins/` and run `pnpm build`.

## Troubleshooting

**"No Vencord or Equicord source folder was found"**
You are probably using the normal installer version. Set up a source build using the guides in [Before you start](#before-you-start), or pick your folder manually when the installer asks.

**"Git / Node.js / pnpm was not found"**
Install the missing tool, open a new window and run the installer again.

**The build failed**
The installer shows the real `pnpm build` output and stops. Common fixes: run `pnpm install --frozen-lockfile` in the source folder, or update the source folder with `git pull`. Then run the installer again.

**The plugin does not appear in Settings > Plugins**
Discord must be loading the build from your source folder. Run `pnpm inject` in the source folder (with Discord fully closed), then restart Discord.

**The plugin is on but I still see `+n`**
Discord may have changed its code. Open the console (`Ctrl+Shift+I` / `Cmd+Option+I`) and look for a patch failure mentioning ShowAllBadges, then open an issue with that output.

**Equicord: the plugin turns itself off**
Recent Equicord sources move it to **EquiTweaks > Show All Badges** (see [compatibility](#vencord-and-equicord-compatibility)). Badges are still shown through that option.

**macOS: "cannot be opened because it is from an unidentified developer"**
Right-click the `.command` file and choose **Open**. If it says permission denied, run `chmod +x installers/macos/*.command installers/macos/*.sh` in Terminal.

**Windows: the window closes or scripts are blocked**
Use `install.bat`, not `install.ps1` directly. The `.bat` file starts PowerShell with the right options for this one run only.

## How it works

Discord's profile badge list asks a feature gate whether to use a collapsed layout: a few badges, then a `+n` chip that opens the rest in a popout. The plugin answers "no" at the point where the list asks, so Discord draws its regular rows with every badge.

```ts
find: 'location:"UserProfileBadgeListRows"',
replacement: {
    match: /\(0,\i\.\i\)\(\{location:"UserProfileBadgeListRows"\}\)/,
    replace: "!1"
}
```

Limitations:

- Vencord and Equicord have no API for this, so it is a code patch. When Discord changes that part of its client the patch can stop matching, and the plugin then does nothing until it is updated.
- Bot profiles and your own profile's edit button are unaffected, because Discord handles those separately.
- It does not conflict with Equicord's own EquiTweaks option. Both can be on at the same time.

## What has been tested

- Plugin: type-checked and built inside current Vencord and Equicord sources. The patch was matched against the live Discord stable bundle.
- macOS scripts: `bash -n`, ShellCheck, and full install / uninstall runs **on Linux** with real Vencord and Equicord checkouts (paths with spaces, missing tools, missing source folder, failed build, backups, unrelated plugins kept).
- Windows scripts: PowerShell parser check and the same scenarios run with **PowerShell 7 on Linux**.
- Not yet tested on a real Windows or macOS machine, and not yet tested inside a running Discord client. Reports are welcome.

## Author

ShowAllBadges is a project by [TheAstroMirth](https://github.com/TheAstroMirth), who created and maintains the plugin, the Windows and macOS installers and uninstallers, the platform detection, the scripts and this documentation.

Issues and suggestions: <https://github.com/TheAstroMirth/ShowAllBadges/issues>

## License and third-party notices

Copyright (c) 2026 TheAstroMirth. Licensed under GPL-3.0-or-later, see [LICENSE](LICENSE).

The plugin and the installers are original work by TheAstroMirth. Provenance and third-party notes are in [NOTICE](NOTICE).
