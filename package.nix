{
  lib,
  stdenv,
  fetchFromGitea,
  deps,
  cmake,
  ninja,
  pkg-config,
  makeWrapper,
  qt6Packages,
  gtk3,
  gsettings-desktop-schemas,
  wrapGAppsHook3,
  vulkan-loader,
  glslang,
  boost,
  ffmpeg,
  fmt,
  libopus,
  libusb1,
  libva,
  lz4,
  nlohmann_json,
  openssl,
  zlib,
  zstd,
  libzip,
  nv-codec-headers-12,
  protobuf,
  alsa-lib,
  libpulseaudio,
  pipewire,
  dbus,
  libGL,
  libdrm,
  libxkbcommon,
  wayland,
  wayland-protocols,
  wayland-scanner,
  libdecor,
  udev,
  libx11,
  libxext,
  libxcursor,
  libxi,
  libxrandr,
  libxfixes,
  libxscrnsaver,
  libxcb,
  libxtst,
}:

let
  rev = "f6e768603881713b126cba6f0f5a035981da3b1d";
  version = "0.2.0-rc2-unstable-2026-09-04";

  bundled = [
    "enet"
    "simpleini"
    "cubeb"
    "discord-rpc"
    "spirv-headers"
    "vulkan-memory-allocator"
    "gamemode"
    "frozen"
    "quazip"
    "libusb"
    "httplib"
    "cpp-jwt"
    "sdl3"
    "sirit"
    "tzdb"
    "vulkan-headers"
    "vulkan-utility-libraries"
  ]
  ++ lib.optional stdenv.hostPlatform.isx86_64 "xbyak"
  ++ lib.optional stdenv.hostPlatform.isAarch64 "oaknut";

  stage =
    key:
    "stageDep ${deps.${key}.archive} ${deps.${key}.cacheDir} ${
      lib.escapeShellArgs deps.${key}.patches
    }";
in
stdenv.mkDerivation {
  pname = "eden";
  inherit version;

  src = fetchFromGitea {
    domain = "git.eden-emu.dev";
    owner = "eden-emu";
    repo = "eden";
    inherit rev;
    hash = "sha256-oJuEmWhRWdFGQpbvMIH45ilhaRouHvW+hkK5n8KPNa0=";
    fetchSubmodules = true;
  };

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
    qt6Packages.wrapQtAppsHook
    wrapGAppsHook3
    makeWrapper
    qt6Packages.qttools
    glslang
    protobuf
    wayland-scanner
  ];

  buildInputs = [
    qt6Packages.qtbase
    qt6Packages.qtcharts
    qt6Packages.qtmultimedia
    qt6Packages.qtwayland
    qt6Packages.qtwebengine

    # eden's Qt file dialog uses the GTK backend, which aborts without org.gtk.Settings.FileChooser
    gtk3
    gsettings-desktop-schemas

    vulkan-loader

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
    protobuf
    openssl
    zlib
    zstd

    alsa-lib
    libpulseaudio
    pipewire

    dbus
    libGL
    libdrm
    libxkbcommon
    wayland
    wayland-protocols
    libdecor
    udev
    libx11
    libxext
    libxcursor
    libxi
    libxrandr
    libxfixes
    libxscrnsaver
    libxcb
    libxtst
  ];

  preConfigure = ''
    export CPM_SOURCE_CACHE=$PWD/.cache/cpm

    stageDep() {
      local archive=$1 dir=$CPM_SOURCE_CACHE/$2
      shift 2
      local unpacked
      unpacked=$(mktemp -d)
      tar -xf "$archive" -C "$unpacked"
      mapfile -t entries < <(find "$unpacked" -mindepth 1 -maxdepth 1)
      mkdir -p "$(dirname "$dir")"
      if [ "''${#entries[@]}" -eq 1 ] && [ -d "''${entries[0]}" ]; then
        mv "''${entries[0]}" "$dir"
      else
        mv "$unpacked" "$dir"
      fi
      chmod -R u+w "$dir"
      local key=none
      if [ "$#" -gt 0 ]; then
        for p in "$@"; do
          patch -d "$dir" -p1 -i "$PWD/$p"
        done
        key=$(cat "$@" | sha512sum | cut -d ' ' -f 1)
      fi
      printf '%s' "$key" > "$dir/.cpm_patch_key"
    }

    ${lib.concatMapStringsSep "\n" stage bundled}
  '';

  cmakeFlags = [
    "-DFETCHCONTENT_FULLY_DISCONNECTED=ON"
    "-DVulkanHeaders_FORCE_BUNDLED=ON"
    "-DYUZU_TESTS=OFF"
    "-DYUZU_BUILD_PRESET=generic"
    "-DENABLE_QT=ON"
    "-DENABLE_QT_TRANSLATION=OFF"
    "-DYUZU_USE_QT_MULTIMEDIA=ON"
    "-DYUZU_USE_QT_WEB_ENGINE=ON"
    "-DYUZU_USE_BUNDLED_SDL3=OFF"
    "-DYUZU_USE_BUNDLED_FFMPEG=OFF"
    "-DYUZU_USE_EXTERNAL_FFMPEG=OFF"
    "-DENABLE_CUBEB=ON"
    "-DUSE_DISCORD_PRESENCE=ON"
    "-DENABLE_UPDATE_CHECKER=OFF"
    "-DENABLE_WEB_SERVICE=ON"
  ];

  qtWrapperArgs = [
    "--prefix LD_LIBRARY_PATH : ${vulkan-loader}/lib"
  ];

  dontWrapGApps = true;
  preFixup = ''
    qtWrapperArgs+=("''${gappsWrapperArgs[@]}")
  '';

  postInstall = ''
    install -Dm644 $src/dist/72-eden-input.rules $out/lib/udev/rules.d/72-eden-input.rules
    install -Dm644 $src/dist/dev.eden_emu.eden.desktop $out/share/applications/dev.eden_emu.eden.desktop
    install -Dm644 $src/dist/dev.eden_emu.eden.svg $out/share/icons/hicolor/scalable/apps/dev.eden_emu.eden.svg
    install -Dm644 $src/dist/dev.eden_emu.eden.metainfo.xml $out/share/metainfo/dev.eden_emu.eden.metainfo.xml
  '';

  meta = with lib; {
    description = "Nintendo Switch Emulator (Eden community fork)";
    homepage = "https://eden-emu.dev";
    license = licenses.gpl3Plus;
    maintainers = [ ];
    platforms = [
      "x86_64-linux"
      "aarch64-linux"
    ];
    mainProgram = "eden";
  };
}
