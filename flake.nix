{
  description = "Eden Emulator - Nintendo Switch Emulator for NixOS";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    git-hooks = {
      url = "github:cachix/git-hooks.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      git-hooks,
    }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems =
        fn:
        nixpkgs.lib.genAttrs supportedSystems (
          system:
          fn {
            pkgs = import nixpkgs { localSystem.system = system; };
            inherit system;
          }
        );
    in
    {
      packages = forAllSystems (
        { pkgs, system }:
        let
          deps = import ./deps { inherit pkgs; };
        in
        {
          eden = pkgs.callPackage ./package.nix { inherit deps; };
          default = self.packages.${system}.eden;
        }
      );

      formatter = forAllSystems ({ pkgs, ... }: pkgs.nixfmt);

      checks = forAllSystems (
        { system, ... }:
        {
          pre-commit-check = git-hooks.lib.${system}.run {
            src = self;
            hooks.nixfmt-rfc-style.enable = true;
            hooks.typos.enable = true;
            hooks.rumdl.enable = true;
            hooks.check-readme-sections = {
              enable = true;
              name = "check-readme-sections";
              entry = "bash scripts/check-readme-sections.sh";
              files = "README\.md$";
              language = "system";
            };
          };
        }
      );

      devShells = forAllSystems (
        { pkgs, system }:
        {
          # Development shell for working on Eden
          default = pkgs.mkShell {
            inherit (self.checks.${system}.pre-commit-check) shellHook;
            inputsFrom = [ self.packages.${system}.eden ];
            buildInputs = self.checks.${system}.pre-commit-check.enabledPackages;
            packages = with pkgs; [
              cmake
              ninja
              ccache
              nil
            ];
          };

          # Android APK build shell
          android =
            let
              androidPkgs = import nixpkgs {
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
        }
      );

      # NixOS module for easy integration
      nixosModules.default =
        {
          config,
          lib,
          pkgs,
          ...
        }:
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
