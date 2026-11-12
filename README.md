# Eden (Nix)

A Nix flake for [Eden](https://eden-emu.dev), the Nintendo Switch emulator,
built from upstream's master branch. It is for NixOS users who want Eden
installed declaratively, through a module. It also carries a dev shell for
building Eden's Android APK on NixOS.

The flake declares `x86_64-linux` and `aarch64-linux`. A new upstream revision
reaches `main` only after the checks and a full build have passed. Nothing here
starts the emulator or a game, so whether a given game runs is untested.

## Install

Add the flake:

```nix
{
  inputs.eden = {
    url = "github:Daaboulex/eden-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
}
```

Then add the overlay, import the module and switch it on:

```nix
{
  imports = [ inputs.eden.nixosModules.default ];
  nixpkgs.overlays = [ inputs.eden.overlays.default ];

  programs.eden.enable = true;
}
```

This installs Eden with its desktop entry and its udev rules for controllers.
The module takes its package from `pkgs.eden`, which the overlay provides.

To try Eden without installing it, build it from a clone:

```bash
git clone https://github.com/Daaboulex/eden-nix
cd eden-nix
nix build
./result/bin/eden
```

## Use

Start Eden from the application menu, or run `eden` in a terminal.
`eden --help` shows the command-line options.

Before the first game:

1. Place your Switch firmware in `~/.local/share/eden/nand/system/Contents/registered/`.
2. Place your `prod.keys` in `~/.local/share/eden/keys/`.
3. Add game files (NSP or XCI) through File, then Open, or through the game
   directory setting.

## Options

The module has two options. `programs.eden.enable` installs Eden.
`programs.eden.package` chooses the Eden package to use, `pkgs.eden` by default.

Every option, with its type and default: [docs/OPTIONS.md](docs/OPTIONS.md).

## Building the Android APK

The `android` dev shell builds the Eden APK on NixOS. It provides the Android
SDK (API 36), NDK 28, JDK 21, CMake and the environment variables the build
needs.

```bash
git clone --recurse-submodules https://git.eden-emu.dev/eden-emu/eden.git
cd eden
nix develop github:Daaboulex/eden-nix#android
cd src/android && ./gradlew assembleRelease
```

The Android SDK packages are unfree. The shell accepts their license itself, so
no `--impure` flag is needed.

## Known limits

- Firmware, keys and games are yours to supply.
- The package follows upstream's master branch, not its tagged releases.
- The interface translations are not built.
- Eden's own update checker is switched off.

## When something does not work

The package is updated by a scheduled job. When an update fails its checks or
its build, `main` stays on the last revision that passed and a GitHub issue is
opened with the failure and the build output. Look at the
[issues](https://github.com/Daaboulex/eden-nix/issues) first when the package
lags behind upstream.

To report a security problem, follow [SECURITY.md](SECURITY.md).

## More

- [docs/DESIGN.md](docs/DESIGN.md): how Eden's bundled dependencies reach a
  sandboxed build, what the module does, why the Android shell is separate
- [docs/DEVELOPMENT.md](docs/DEVELOPMENT.md): building, the checks, the Android
  shell in detail, how the automatic update works
- [Eden upstream](https://git.eden-emu.dev/eden-emu/eden): the emulator's own
  source

## License

The Nix packaging code is [MIT](./LICENSE) licensed. Upstream Eden is [GPL-3.0-or-later](https://git.eden-emu.dev/eden-emu/eden/src/branch/master/LICENSE.txt).
