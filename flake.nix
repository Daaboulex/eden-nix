{
  description = "Eden Emulator - Nintendo Switch Emulator for NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    std = {
      url = "github:Daaboulex/nix-packaging-standard?ref=v2.5.0";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.git-hooks.follows = "git-hooks";
    };
  };

  outputs =
    inputs@{ flake-parts, self, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];

      imports = [ inputs.std.flakeModules.base ];

      flake.overlays.default = _final: prev: {
        eden = self.packages.${prev.stdenv.hostPlatform.system}.eden;
      };
      flake.nixosModules.default = import ./module.nix;

      perSystem =
        {
          config,
          lib,
          system,
          pkgs,
          self',
          ...
        }:
        {
          packages.eden = pkgs.callPackage ./package.nix {
            deps = import ./deps { inherit pkgs; };
          };
          packages.default = self'.packages.eden;

          # `nix develop` — build + lint shell. Overrides the standard's
          # lint-only default to add Eden's C++ build toolchain, while still
          # carrying the pre-commit hooks via the pre-commit devShell.
          devShells.default = lib.mkForce (
            pkgs.mkShell {
              inputsFrom = [
                config.pre-commit.devShell
                self'.packages.eden
              ];
              packages = with pkgs; [
                cmake
                ninja
                ccache
                nil
              ];
            }
          );

          # `nix develop .#android` — Android APK build environment. Uses a
          # separate nixpkgs import that accepts the (unfree) Android SDK
          # licenses, so the main package/dev shells stay free.
          devShells.android =
            let
              androidPkgs = import inputs.nixpkgs {
                localSystem.system = system;
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
                ndkVersion = "28.2.13676358";
              };
              androidSdk = androidComposition.androidsdk;
            in
            androidPkgs.mkShell {
              packages = with androidPkgs; [
                androidSdk
                jdk
                git
                cacert
                ninja
                pkg-config
                glslang
                openssl
              ];

              GRADLE_OPTS = "-Dorg.gradle.project.android.aapt2FromMavenOverride=${androidSdk}/libexec/android-sdk/build-tools/${buildToolsVersion}/aapt2";

              shellHook = ''
                # Create a mutable copy of the Android SDK so Gradle can install
                # additional components (platform revisions, etc.) at runtime
                export ANDROID_SDK_MUTABLE="$HOME/.cache/eden-android-sdk"
                if [ ! -d "$ANDROID_SDK_MUTABLE" ]; then
                  echo "Creating mutable Android SDK copy (first time only)..."
                  mkdir -p "$ANDROID_SDK_MUTABLE"
                  cp -r ${androidSdk}/libexec/android-sdk/* "$ANDROID_SDK_MUTABLE/"
                  chmod -R u+w "$ANDROID_SDK_MUTABLE"
                fi

                export ANDROID_HOME="$ANDROID_SDK_MUTABLE"
                export ANDROID_SDK_ROOT="$ANDROID_SDK_MUTABLE"
                export ANDROID_NDK_ROOT="$ANDROID_SDK_MUTABLE/ndk-bundle"
                export PATH="${androidSdk}/libexec/android-sdk/cmake/${cmakeVersion}/bin:$PATH"

                echo "Eden Android DevShell activated!"
                echo "   ANDROID_HOME=$ANDROID_HOME"
                echo ""
                echo "To build the APK:"
                echo "   cd src/android && ./gradlew assembleRelease"
              '';
            };

          checks.module-eval-nixos = inputs.std.lib.nixosModuleCheck {
            inherit (inputs) nixpkgs;
            inherit system;
            overlays = [ self.overlays.default ];
            module = ./module.nix;
            config.programs.eden.enable = true;
          };
        };
    };
}
