# Options

Every option the modules of this flake declare. This file is generated from the module sources: change a description there, then run `nix run .#std-write-option-reference`.

## NixOS module

Declared in [module.nix](../module.nix).

### `programs.eden.enable`

Whether to enable Eden Nintendo Switch Emulator.

- Type: boolean
- Default: `false`

### `programs.eden.package`

The Eden package to use.

- Type: package
- Default: `pkgs.eden`
