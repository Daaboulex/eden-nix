{
  description = "Eden Emulator - Nintendo Switch Emulator for NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" ] (system:
      let
        pkgs = import nixpkgs { inherit system; };
        deps = import ./deps { inherit pkgs; };
      in
      {
        packages = {
          eden = pkgs.callPackage ./package.nix { inherit deps; };
          default = self.packages.${system}.eden;
        };

        # Development shell for working on Eden
        devShells.default = pkgs.mkShell {
          inputsFrom = [ self.packages.${system}.eden ];
          packages = with pkgs; [
            cmake
            ninja
            ccache
          ];
        };
      }
    ) // {
      # NixOS module for easy integration
      nixosModules.default = { config, lib, pkgs, ... }:
        let
          cfg = config.programs.eden;
        in
        {
          options.programs.eden = {
            enable = lib.mkEnableOption "Eden Nintendo Switch Emulator";
            package = lib.mkOption {
              type = lib.types.package;
              default = self.packages.${pkgs.stdenv.hostPlatform.system}.eden;
              description = "The Eden package to use";
            };
          };

          config = lib.mkIf cfg.enable {
            environment.systemPackages = [ cfg.package ];
            # Add udev rules for controller support
            services.udev.packages = [ cfg.package ];
          };
        };

      # Overlay for including in other flakes
      overlays.default = final: prev: {
        eden = self.packages.${prev.stdenv.hostPlatform.system}.eden;
      };
    };
}
