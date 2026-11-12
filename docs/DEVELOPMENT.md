# Development

```bash
git clone https://github.com/Daaboulex/eden-nix
cd eden-nix
nix develop
nix fmt
nix flake check --no-build
nix build
./result/bin/eden
```

`nix develop` enters the dev shell and installs the pre-commit hooks. `nix fmt`
formats the flake. `nix flake check --no-build` is the evaluation check.
`nix build` builds the package, and running `./result/bin/eden` verifies the
binary.

The default dev shell carries Eden's own build inputs along with `cmake`,
`ninja`, `ccache` and `nil`.

The flake follows `nixos-unstable` and declares `x86_64-linux` and
`aarch64-linux`.

## Checks

`checks.module-eval-nixos` evaluates the NixOS module with
`programs.eden.enable = true` against the flake's own overlay. The lint hooks
and the remaining checks come from
[nix-packaging-standard](https://github.com/Daaboulex/nix-packaging-standard),
which the flake imports as `std`.

CI is [`ci.yml`](../.github/workflows/ci.yml). It runs on a push to `main` and
on a pull request, and its status is on the
[Actions page](https://github.com/Daaboulex/eden-nix/actions/workflows/ci.yml).

## The Android shell

`nix develop .#android` gives the environment for building the Eden APK. The
SDK it composes holds:

| Part | Version |
|---|---|
| Platform | API 36 |
| Build tools | 35.0.0 |
| NDK | 28.2.13676358 |
| CMake | 3.22.1 |
| ABI | arm64-v8a |

Beside the SDK the shell carries nixpkgs' `jdk`, which is JDK 21 at the pinned
nixpkgs, and `git`, `cacert`, `ninja`, `pkg-config`, `glslang` and `openssl`.

The shell sets `ANDROID_HOME` and `ANDROID_SDK_ROOT` to its writable copy of
the SDK and `ANDROID_NDK_ROOT` to the NDK inside it. It sets `GRADLE_USER_HOME`
and `ANDROID_USER_HOME`, points Gradle's aapt2 at the SDK's build tools through
`GRADLE_OPTS`, and puts the SDK's CMake first on `PATH`.

The first entry prints "Creating mutable Android SDK copy (first time only)..."
while it copies the SDK. [DESIGN.md](DESIGN.md) says why the copy exists.

## Updates

This flake automatically tracks the latest Eden master branch via GitHub
Actions. What it tracks is the Gitea commits of
[eden-emu/eden](https://git.eden-emu.dev/eden-emu/eden), named in
[`.github/update.json`](../.github/update.json).

- [`update.yml`](../.github/workflows/update.yml) is scheduled at 6 AM UTC. It
  runs daily unless the repository variable `UPDATE_CADENCE` is set to
  `weekly`, which leaves only the Sunday run. It can also be started by hand
  from the Actions tab: choose "Update", then "Run workflow".
- [`scripts/update.sh`](../scripts/update.sh) reads the newest commit of
  upstream's branch from the Gitea API, bumps the pinned revision, re-vendors
  upstream's `cpmfile.json` at that revision, and recomputes the source hash.
- The updater then runs `nix flake check`, then a full build, before any push
  to `main`.
- A dependency Eden newly bundles surfaces as a configure-time download attempt
  in the sandbox, so the build fails instead of fetching silently.
- A bundled dependency that upstream renames or removes fails earlier, before
  the source is fetched, and the updater says that the manifest no longer
  matches `package.nix`.
- When more than one fixed-output hash mismatches, a manifest hash disagrees
  with its archive, and the updater stops for manual review.
- If the build passes, changes are pushed directly to `main`.
- If the build fails, a GitHub issue is opened with the classified failure and
  build output.

### The version string

A version reads `<release>-unstable-<date>`: upstream's newest release tag, then
the date of the pinned commit.

The release part is refetched on every bump. Reading it back out of the current
version only echoes whatever it was first set to, which is how this package
kept calling itself 0.2.0-rc2 long after upstream shipped 0.2.0 and 0.2.1.

Only tags shaped like a release number count. Upstream carries tags like
`test-tag2`, `0.0.3.git` and `0.0.4.test`, and a plain version sort ranks every
one of them above the newest release.
