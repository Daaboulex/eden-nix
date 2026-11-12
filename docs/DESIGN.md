# Design

Why the packaging is built the way it is. The [README](../README.md) says how to use it.

## Bundled dependencies in a sandboxed build

Eden uses CPM (CMake Package Manager) to fetch dependencies at build time from
the manifest `cpmfile.json`. Nix builds are sandboxed without network access, so
that fetch cannot happen inside the build.

This flake vendors the manifest at the pinned revision as
[`deps/cpmfile.json`](../deps/cpmfile.json). It is Eden's own `cpmfile.json`,
and every bundled dependency's URL and hash derive from it.

[`deps/default.nix`](../deps/default.nix) turns each manifest entry into a
fetch, checked against the sha512 the entry declares. The URL is the one the
entry declares. When it declares none, the URL is the release artifact or the
source archive of the repository and version the entry names. Entries the
manifest marks `ci` are left out.

[`package.nix`](../package.nix) names the entries the build uses in its
`bundled` list, with `xbyak` added on x86_64 and `oaknut` on aarch64. Before
CMake configures, it stages each one into the CPM cache: it unpacks the
archive, applies the patches the manifest lists for it from Eden's `.patch/`
directory, and writes the patch key Eden's own CPMUtil expects. CMake runs with
`FETCHCONTENT_FULLY_DISCONNECTED=ON`.

## Vulkan

The Vulkan dependencies (`vulkan-headers` and `vulkan-utility-libraries`) are
bundled together via CPM to avoid version mismatches with system packages. The
build sets `VulkanHeaders_FORCE_BUNDLED=ON`.

The Vulkan loader comes from nixpkgs. The wrapper puts it on the library path.

## The file dialog

Eden's Qt file dialog uses the GTK backend, which aborts without the
`org.gtk.Settings.FileChooser` schema. The package therefore takes `gtk3` and
`gsettings-desktop-schemas` as build inputs and hands the GApps wrapper
arguments to the Qt wrapper.

## Build switches

Switched off in [`package.nix`](../package.nix):

- the interface translations (`ENABLE_QT_TRANSLATION`)
- Eden's update checker (`ENABLE_UPDATE_CHECKER`)
- the tests (`YUZU_TESTS`)
- warnings as errors (`ENABLE_WERROR`)

Switched on: the Qt interface with Qt Multimedia and Qt WebEngine, cubeb,
Discord presence and the web service.

## The module

[`module.nix`](../module.nix) declares `programs.eden.enable` and
`programs.eden.package`. Enabling it adds the package to the system packages
and to `services.udev.packages`.

The udev entry is what gives controllers hotplug access. The package installs
upstream's `72-eden-input.rules`, along with the desktop entry, the icon and
the metainfo file.

## The Android shell

The `android` dev shell imports nixpkgs a second time, with the Android SDK
license accepted and unfree packages allowed. The package and the default dev
shell use the ordinary import, so they stay free. This is also why entering the
shell needs no `--impure` flag.

On first entry the shell copies the SDK out of the Nix store into a writable
directory, so that Gradle can install additional components, such as platform
revisions, at run time. The copy, Gradle's home and the Android user home all
sit in `.devshell/` at the root of the checkout the shell is entered from.
