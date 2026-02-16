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
, vulkan-headers
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
  # Last updated: 2025-12-22
  rev = "3413fbd9da657a9b92398256ffe3bf3b4ac005ee";
  version = "0.0.4-unstable-2025-12-22";
in
stdenv.mkDerivation {
  pname = "eden";
  inherit version;

  src = fetchFromGitea {
    domain = "git.eden-emu.dev";
    owner = "eden-emu";
    repo = "eden";
    inherit rev;
    hash = "sha256-uAGAo+CM2aUOhjj34SOqzYNauGH9dTxXYEDTU/5uY3k=";
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
    qt6Packages.qtmultimedia
    qt6Packages.qtwayland
    qt6Packages.qtwebengine

    # Vulkan
    vulkan-headers
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
      copyDep ${deps.xbyak} xbyak/7.22
    ''}

    copyDep ${deps.enet} enet/1.3.18
    copyDep ${deps.simpleini} simpleini/4.25
    copyDep ${deps.cubeb} cubeb/fa02
    copyDep ${deps.discord-rpc} discordrpc/1cf7
    copyDep ${deps.spirv-headers} spirv-headers/01e0
    copyDep ${deps.spirv-tools} spirv-tools/2fa2
    copyDep ${deps.vma} vulkanmemoryallocator/3.3.0
    copyDep ${deps.unordered-dense} unordered_dense/4.8.1
    copyDep ${deps.gamemode} gamemode/ce6f
    copyDep ${deps.frozen} frozen/61dc
    copyDep ${deps.quazip} quazip-qt6/f838
    copyDep ${deps.mcl} mcl/7b08
    copyDep ${deps.libusb} libusb/1.0.29
    copyDep ${deps.httplib} httplib/0.28.0
    copyDep ${deps.cpp-jwt} cpp-jwt/9eae

    # Archives that need extraction (fetchurl - not directories)
    extractDep ${deps.mbedtls} mbedtls/3.6.4
    extractDep ${deps.sirit} sirit/1.0.3
    extractDep ${deps.nx-tzdb} nx_tzdb/121125

    # VulkanUtilityHeaders - zst archive without subdirectory, extract without strip
    mkdir -p "$CPM_SOURCE_CACHE/vulkanutilitylibraries/1.4.328"
    zstd -d ${deps.vulkan-utility-libraries} -c | tar -x -C "$CPM_SOURCE_CACHE/vulkanutilitylibraries/1.4.328"
    chmod -R u+w "$CPM_SOURCE_CACHE/vulkanutilitylibraries/1.4.328"

    ${lib.optionalString stdenv.hostPlatform.isAarch64 ''
      copyDep ${deps.oaknut} oaknut/2.0.2
    ''}
  '';

  cmakeFlags = [
    # Disable network fetching - use pre-populated cache
    "-DFETCHCONTENT_FULLY_DISCONNECTED=ON"

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
