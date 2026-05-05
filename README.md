# eden-nix

<!-- BEGIN generated:badges -->
[![NixOS unstable](https://img.shields.io/badge/NixOS-unstable-78C0E8?logo=nixos&logoColor=white)](https://nixos.org)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](./LICENSE)
<!-- END generated:badges -->

Nix flake for the [Eden](https://eden-emu.dev) Nintendo Switch emulator.

<!-- BEGIN generated:upstream -->
## Upstream

| | |
|---|---|
| **Project** | [eden-emu/eden](https://git.eden-emu.dev/eden-emu/eden) |
| **License** | GPL-3.0 |
| **Tracked** | Gitea commits |
<!-- END generated:upstream -->

## What Is This?

A Nix flake that builds Eden from upstream master with full CI infrastructure:

- **Daily automated updates** via GitHub Actions — new master commits land here within 24 h
- **CPM dependency sync** — `scripts/sync-deps.py` mirrors `cpmfile.json` and pre-fetches all sources for the sandboxed Nix build
- **Pre-build verification** — fail-closed pipeline (eval → build → ELF check) before any push to `main`
- **NixOS module** — exposes `programs.eden.enable` for declarative install
- **Android devshell** — bundled SDK/NDK environment for building the Eden APK on NixOS

**This package tracks the latest master branch** with daily automated updates via GitHub Actions.

<!-- BEGIN generated:installation -->
## Installation

### As a flake input

```nix
{
  inputs.eden.url = "github:daaboulex/eden-nix";

  outputs = { nixpkgs, eden, ... }: {
    nixosConfigurations.myhost = nixpkgs.lib.nixosSystem {
      modules = [
        ({ pkgs, ... }: {
          environment.systemPackages = [ eden.packages.${pkgs.system}.eden ];
        })
      ];
    };
  };
}
```

### Using the NixOS module

```nix
{
  imports = [ eden.nixosModules.default ];
  programs.eden.enable = true;
}
```

### Direct run

```bash
nix run github:daaboulex/eden-nix
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

Eden uses CPM (CMake Package Manager) to fetch dependencies at build time. Since Nix builds are sandboxed without network access, this flake pre-fetches all CPM dependencies and injects them into the build cache.

The Vulkan dependencies (`vulkan-headers` and `vulkan-utility-libraries`) are bundled together via CPM to avoid version mismatches with system packages.

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
- `scripts/sync-deps.py` synchronizes all CPM dependencies with upstream `cpmfile.json` — tag-based, commit-based, and release artifact deps are all handled
- URL + hash updates are atomic (can never desync)
- New upstream CPM dependencies are detected and flagged for manual addition
- CMakeLists.txt `find_package()` changes are diffed to catch new system dependency requirements
- If the build passes, changes are pushed directly to main
- If the build fails, a GitHub issue is opened with dependency warnings, new dep suggestions, and build output

<!-- BEGIN generated:options -->
<!-- END generated:options -->

## License

This packaging flake is [GPL-3.0-or-later](./LICENSE) licensed (matches upstream). Upstream Eden is [GPL-3.0-or-later](https://git.eden-emu.dev/eden-emu/eden/src/branch/master/LICENSE.txt).

<!-- BEGIN generated:footer -->
---

*Maintained as part of the [Daaboulex](https://github.com/Daaboulex) NixOS ecosystem.*
<!-- END generated:footer -->
