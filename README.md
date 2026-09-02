# eden-nix

<!-- BEGIN generated:badges -->
[![CI](https://github.com/Daaboulex/eden-nix/actions/workflows/ci.yml/badge.svg)](https://github.com/Daaboulex/eden-nix/actions/workflows/ci.yml)
[![NixOS unstable](https://img.shields.io/badge/NixOS-unstable-78C0E8?logo=nixos&logoColor=white)](https://nixos.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)
<!-- END generated:badges -->

Nix flake for the [Eden](https://eden-emu.dev) Nintendo Switch emulator.

<!-- BEGIN generated:upstream -->
## Upstream

| | |
|---|---|
| **Project** | [eden-emu/eden](https://git.eden-emu.dev/eden-emu/eden) |
| **License** | GPL-3.0-or-later |
| **Tracked** | Gitea commits |

<!-- END generated:upstream -->

## What Is This?

A Nix flake that builds Eden from upstream master with full CI infrastructure:

- **Daily automated updates** via GitHub Actions — new master commits land here within 24 h
- **CPM dependencies from upstream's own manifest** — `deps/cpmfile.json` is Eden's `cpmfile.json` vendored at the pinned revision; every bundled dependency's URL and hash derive from it
- **Pre-build verification** — fail-closed pipeline (eval → build → ELF check) before any push to `main`
- **NixOS module** — exposes `programs.eden.enable` for declarative install
- **Android devshell** — bundled SDK/NDK environment for building the Eden APK on NixOS

**This package tracks the latest master branch** with daily automated updates via GitHub Actions.

<!-- BEGIN generated:installation -->
## Installation

Add as a flake input:

```nix
{
  inputs.eden = {
    url = "github:Daaboulex/eden-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
}
```

Then add the overlay:

```nix
nixpkgs.overlays = [ inputs.eden.overlays.default ];
```

Import the NixOS module:

```nix
imports = [ inputs.eden.nixosModules.default ];
```

<!-- END generated:installation -->

## Build from source

```bash
git clone https://github.com/daaboulex/eden-nix
cd eden-nix
nix build
./result/bin/eden
```

## Android APK Build

An Android devshell is included for building the Eden APK on NixOS. It provides the Android SDK (API 36), NDK 28, JDK 21, CMake, and all necessary environment variables.

```bash
# Clone Eden source
git clone --recurse-submodules https://git.eden-emu.dev/eden-emu/eden.git
cd eden

# Enter the Android devshell
nix develop github:daaboulex/eden-nix#android

# Build the APK
cd src/android && ./gradlew assembleRelease
```

> **Note:** The Android SDK packages are unfree. The devshell handles license acceptance automatically — no `--impure` flag needed.

## How it works

Eden uses CPM (CMake Package Manager) to fetch dependencies at build time from the manifest `cpmfile.json`. Since Nix builds are sandboxed without network access, this flake vendors that manifest at the pinned revision (`deps/cpmfile.json`), fetches every bundled dependency from the URL and sha512 it declares (`deps/default.nix`), and stages them into the CPM cache with the patches and patch key Eden's own CPMUtil expects (`package.nix`).

The Vulkan dependencies (`vulkan-headers` and `vulkan-utility-libraries`) are bundled together via CPM to avoid version mismatches with system packages.

## Usage

Enable Eden via the NixOS module:

```nix
{
  programs.eden = {
    enable = true;
  };
}
```

This installs the Eden binary and creates a `.desktop` entry. Launch from your application menu or terminal:

```bash
eden                     # launch the GUI
eden --help              # show CLI options
```

### First-time setup

1. Place your Switch firmware in `~/.local/share/eden/nand/system/Contents/registered/`
2. Place your `prod.keys` in `~/.local/share/eden/keys/`
3. Add game files (NSP/XCI) via **File → Open** or the game directory setting

## Development

```bash
git clone https://github.com/Daaboulex/eden-nix
cd eden-nix
nix develop                       # enter dev shell, installs pre-commit hooks
nix fmt                           # format flake
nix flake check --no-build        # eval check
nix build                         # build the package
./result/bin/eden                 # binary verify
```

CI runs the same chain daily; manual updates rarely needed.

## Updating

This flake automatically tracks the latest Eden master branch via GitHub Actions:

- A workflow runs daily at 6 AM UTC (or manually via Actions → "Update Eden" → "Run workflow")
- `scripts/update.sh` bumps the pinned revision, re-vendors upstream's `cpmfile.json`, and recomputes the source hash
- A dependency Eden newly bundles surfaces as a configure-time download attempt in the sandbox, so the build fails instead of fetching silently
- If the build passes, changes are pushed directly to main
- If the build fails, a GitHub issue is opened with the classified failure and build output

<!-- BEGIN generated:options -->
## Options

This module declares `programs.eden.{enable,package}`. See [`module.nix`](module.nix) for the module definition.
<!-- END generated:options -->

## License

The Nix packaging code is [MIT](./LICENSE) licensed. Upstream Eden is [GPL-3.0-or-later](https://git.eden-emu.dev/eden-emu/eden/src/branch/master/LICENSE.txt).

<!-- BEGIN generated:footer -->
<!-- END generated:footer -->
