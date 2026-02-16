# eden-nix

Nix flake for the [Eden](https://eden-emu.dev) Nintendo Switch emulator.

Eden is a community-maintained fork that continues active development with performance improvements and new features.

**This package tracks the latest master branch** with daily automated updates via GitHub Actions.

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

## Build from source

```bash
git clone https://github.com/daaboulex/eden-nix
cd eden-nix
nix build
./result/bin/eden
```

## How it works

Eden uses CPM (CMake Package Manager) to fetch dependencies at build time. Since Nix builds are sandboxed without network access, this flake pre-fetches all CPM dependencies and injects them into the build cache.

## Updating

This flake automatically tracks the latest Eden master branch via GitHub Actions:
- A workflow runs daily at 6 AM UTC
- If a new commit is found, a PR is automatically created
- CPM dependency hashes are updated as needed

To manually trigger an update: Go to Actions → "Update Eden" → "Run workflow"

## License

GPL-3.0-or-later (same as Eden)

