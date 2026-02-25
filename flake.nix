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

        # Android APK build shell
        devShells.android = let
          androidPkgs = import nixpkgs {
            inherit system;
            config = {
              android_sdk.accept_license = true;
              allowUnfree = true;
            };
          };
          buildToolsVersion = "35.0.0";
          cmakeVersion = "3.22.1";
          androidComposition = androidPkgs.androidenv.composeAndroidPackages {
            buildToolsVersions = [ buildToolsVersion ];
            platformVersions = [ "36" ];
            cmakeVersions = [ cmakeVersion ];
            abiVersions = [ "arm64-v8a" ];
            includeNDK = true;
            ndkVersion = "28.0.13004108";
          };
          androidSdk = androidComposition.androidsdk;
        in androidPkgs.mkShell {
          packages = with androidPkgs; [
            androidSdk
            jdk
            git
            cacert
            ninja
            pkg-config
          ];

          ANDROID_HOME = "${androidSdk}/libexec/android-sdk";
          ANDROID_SDK_ROOT = "${androidSdk}/libexec/android-sdk";
          ANDROID_NDK_ROOT = "${androidSdk}/libexec/android-sdk/ndk-bundle";
          GRADLE_OPTS = "-Dorg.gradle.project.android.aapt2FromMavenOverride=${androidSdk}/libexec/android-sdk/build-tools/${buildToolsVersion}/aapt2";

          shellHook = ''
            export PATH="${androidSdk}/libexec/android-sdk/cmake/${cmakeVersion}/bin:$PATH"
            echo "🤖 Eden Android DevShell activated!"
            echo "   ANDROID_HOME=$ANDROID_HOME"
            echo ""
            echo "To build the APK:"
            echo "   cd src/android && ./gradlew assembleRelease"
          '';
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
