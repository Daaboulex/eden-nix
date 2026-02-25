# Eden Emulator Package for NixOS
# Based on Eden v0.0.4 from https://git.eden-emu.dev/eden-emu/eden
{ lib
, stdenv
, fetchFromGitea
, deps
, cmake
, ninja
, pkg-config
, makeWrapper
# Qt6
, qt6Packages
# Vulkan
, vulkan-loader
, glslang
# System deps
, boost
, ffmpeg
, fmt
, libopus
, libusb1
, libva
, lz4
, nlohmann_json
, openssl
, SDL2
, zlib
, zstd
, libzip
, nv-codec-headers-12
}:

let
  # Auto-updated by GitHub Actions - do not edit manually
  # Last updated: 2026-02-25
  rev = "0ff84ef312d44b7dc6e3a805dee6a00c03c1df7c";
  version = "0.0.4-unstable-2026-02-25";
in
stdenv.mkDerivation {
  pname = "eden";
  inherit version;

  src = fetchFromGitea {
    domain = "git.eden-emu.dev";
    owner = "eden-emu";
    repo = "eden";
    inherit rev;
    hash = "sha256-LHgdmHk8nunGp2SXT9kQOwZn7WrZXjJv/VYNMm+W/4s=";
    fetchSubmodules = true;
  };

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    qt6Packages.wrapQtAppsHook
    makeWrapper
    qt6Packages.qttools
    glslang
  ];

  buildInputs = [
    # Qt6
    qt6Packages.qtbase
    qt6Packages.qtcharts
    qt6Packages.qtmultimedia
    qt6Packages.qtwayland
    qt6Packages.qtwebengine

    # Vulkan (loader only - headers are bundled via CPM for version matching)
    vulkan-loader

    # System libs
    boost
    ffmpeg
    fmt
    libopus
    libusb1
    libva
    libzip
    lz4
    nlohmann_json
    nv-codec-headers-12
    openssl
    SDL2
    zlib
    zstd
  ];

  # Pre-populate CPM cache with our pre-fetched deps
  # CPM expects: /build/source/.cache/cpm/<name>/<version>/
  # Some deps are archives (fetchurl) that need extraction
  preConfigure = ''
    # CPM looks in .cache/cpm inside source dir
    export CPM_SOURCE_CACHE=$PWD/.cache/cpm
    mkdir -p $CPM_SOURCE_CACHE

    # Helper function to copy and make writable
    copyDep() {
      mkdir -p "$CPM_SOURCE_CACHE/$2"
      cp -r "$1"/* "$CPM_SOURCE_CACHE/$2/" || cp -r "$1" "$CPM_SOURCE_CACHE/$2/"
      chmod -R u+w "$CPM_SOURCE_CACHE/$2"
    }

    # Helper function to extract archive
    extractDep() {
      mkdir -p "$CPM_SOURCE_CACHE/$2"
      tar -xf "$1" -C "$CPM_SOURCE_CACHE/$2" --strip-components=1 2>/dev/null || \
        zstd -d "$1" -c | tar -x -C "$CPM_SOURCE_CACHE/$2" --strip-components=1 2>/dev/null || \
        tar -xjf "$1" -C "$CPM_SOURCE_CACHE/$2" --strip-components=1 2>/dev/null || \
        bzip2 -d -c "$1" | tar -x -C "$CPM_SOURCE_CACHE/$2" --strip-components=1
      chmod -R u+w "$CPM_SOURCE_CACHE/$2"
    }

    # Copy deps to CPM cache with correct version paths
    ${lib.optionalString stdenv.hostPlatform.isx86_64 ''
      copyDep ${deps.xbyak} xbyak/7.33.2
    ''}

    copyDep ${deps.enet} enet/1.3.18
    copyDep ${deps.simpleini} simpleini/4.25
    copyDep ${deps.cubeb} cubeb/fa02
    copyDep ${deps.discord-rpc} discordrpc/0d8b
    copyDep ${deps.spirv-headers} spirv-headers/04f1
    copyDep ${deps.spirv-tools} spirv-tools/0a7e
    copyDep ${deps.vma} vulkanmemoryallocator/3.3.0
    copyDep ${deps.unordered-dense} unordered_dense/7b55
    copyDep ${deps.gamemode} gamemode/ce6f
    copyDep ${deps.frozen} frozen/61dc
    copyDep ${deps.quazip} quazip-qt6/2e95
    copyDep ${deps.mcl} mcl/7b08
    copyDep ${deps.libusb} libusb/1.0.29
    copyDep ${deps.httplib} httplib/0.30.1
    copyDep ${deps.cpp-jwt} cpp-jwt/7f24

    # Archives that need extraction (fetchurl - not directories)
    extractDep ${deps.mbedtls} mbedtls/3.6.4
    extractDep ${deps.sirit} sirit/1.0.3
    extractDep ${deps.nx-tzdb} nx_tzdb/121125

    # Vulkan deps - both must be bundled together to satisfy AddDependentPackages
    copyDep ${deps.vulkan-headers} vulkanheaders/1.4.342
    copyDep ${deps.vulkan-utility-libraries} vulkanutilitylibraries/1.4.342

    ${lib.optionalString stdenv.hostPlatform.isAarch64 ''
      copyDep ${deps.oaknut} oaknut/2.0.3
    ''}
  '';

  cmakeFlags = [
    # Disable network fetching - use pre-populated cache
    "-DFETCHCONTENT_FULLY_DISCONNECTED=ON"

    # Force bundled Vulkan headers to match bundled utility libraries
    "-DVulkanHeaders_FORCE_BUNDLED=ON"

    # Build options
    "-DYUZU_TESTS=OFF"
    "-DYUZU_BUILD_PRESET=generic"  # Safe for binary distribution
    
    # Disable tests for external deps (mbedtls needs Python3)
    "-DENABLE_TESTING=OFF"
    "-DENABLE_PROGRAMS=OFF"

    # Qt6
    "-DENABLE_QT=ON"
    "-DENABLE_QT_TRANSLATION=OFF"
    "-DYUZU_USE_QT_MULTIMEDIA=ON"
    "-DYUZU_USE_QT_WEB_ENGINE=ON"

    # SDL2 - use system
    "-DENABLE_SDL2=ON"
    "-DYUZU_USE_EXTERNAL_SDL2=OFF"
    "-DYUZU_USE_BUNDLED_SDL2=OFF"

    # FFmpeg - use system
    "-DYUZU_USE_BUNDLED_FFMPEG=OFF"
    "-DYUZU_USE_EXTERNAL_FFMPEG=OFF"

    # Audio
    "-DENABLE_CUBEB=ON"

    # Optional features
    "-DUSE_DISCORD_PRESENCE=ON"
    "-DENABLE_UPDATE_CHECKER=OFF"

    # Web services - needed for httplib dep
    "-DENABLE_WEB_SERVICE=ON"
  ];

  qtWrapperArgs = [
    "--prefix LD_LIBRARY_PATH : ${vulkan-loader}/lib"
  ];

  postInstall = ''
    # Install udev rules for controller support
    install -Dm644 $src/dist/72-eden-input.rules $out/lib/udev/rules.d/72-eden-input.rules || true
  '';

  meta = with lib; {
    description = "Nintendo Switch Emulator (Eden community fork)";
    homepage = "https://eden-emu.dev";
    license = licenses.gpl3Plus;
    maintainers = [ ];
    platforms = [ "x86_64-linux" "aarch64-linux" ];
    mainProgram = "eden";
  };
}
