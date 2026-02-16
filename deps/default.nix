# Eden Emulator CPM Dependencies
# These are pre-fetched to work with Nix's sandboxed builds
# URLs and versions from Eden v0.0.4 build logs
{ pkgs }:

{
  # xbyak - JIT assembler for x86/x86_64
  xbyak = pkgs.fetchzip {
    url = "https://github.com/herumi/xbyak/archive/refs/tags/v7.22.tar.gz";
    hash = "sha256-ZmdOjO5MbY+z+hJEVgpQzoYGo5GAFgwAPiv4vs/YMUA=";
  };

  # enet - Reliable UDP networking
  enet = pkgs.fetchzip {
    url = "https://github.com/lsalzman/enet/archive/refs/tags/v1.3.18.tar.gz";
    hash = "sha256-zGSlQnEP8n0Lk4JOHnO2oXEuNDL3z4n+MYsMu2uWW3k=";
  };

  # mbedtls - TLS library
  mbedtls = pkgs.fetchurl {
    url = "https://github.com/Mbed-TLS/mbedtls/releases/download/mbedtls-3.6.4/mbedtls-3.6.4.tar.bz2";
    hash = "sha256-7DWximxZPPmMPjDbi5j/k+iUCoxOaQ5mtB38AR1ngRA=";
  };

  # simpleini - INI parser
  simpleini = pkgs.fetchzip {
    url = "https://github.com/brofield/simpleini/archive/refs/tags/v4.25.tar.gz";
    hash = "sha256-1JTVjMfEuWqlyYAm4Er6HPjrP2Tnt0ntai8oVvIEOu0=";
  };

  # cubeb - Audio library
  cubeb = pkgs.fetchzip {
    url = "https://github.com/mozilla/cubeb/archive/fa02160712.tar.gz";
    hash = "sha256-6PUHUPybe3g5nexunAHsHLThFdvpnv+avks+C0oYih0=";
  };

  # discord-rpc - Discord Rich Presence (Eden fork)
  discord-rpc = pkgs.fetchzip {
    url = "https://github.com/eden-emulator/discord-rpc/archive/1cf7772bb6.tar.gz";
    hash = "sha256-9qosXzeFq00W3pZ+qkePA2swBKliRz9qlbl6QwFT6Qw=";
  };

  # spirv-headers - SPIR-V headers
  spirv-headers = pkgs.fetchzip {
    url = "https://github.com/KhronosGroup/SPIRV-Headers/archive/01e0577914.tar.gz";
    hash = "sha256-gewCQvcVRw+qdWPWRlYUMTt/aXrZ7Lea058WyqL5c08=";
  };

  # spirv-tools - SPIR-V tools (crueter fork)
  spirv-tools = pkgs.fetchzip {
    url = "https://github.com/crueter/SPIRV-Tools/archive/2fa2d44485.tar.gz";
    hash = "sha256-AnDHhutLiu7LrU247mNoMcNyc5VMVmj3dBjxf6q4TKY=";
  };

  # sirit - SPIR-V IR builder (Eden fork)
  sirit = pkgs.fetchurl {
    url = "https://github.com/eden-emulator/sirit/releases/download/v1.0.3/sirit-source-1.0.3.tar.zst";
    hash = "sha256-hwKb3M9XiTAJKZ9KoOjgROWerwi1EVpFhkvQPYxJN7M=";
  };

  # VulkanMemoryAllocator
  vma = pkgs.fetchzip {
    url = "https://github.com/GPUOpen-LibrariesAndSDKs/VulkanMemoryAllocator/archive/refs/tags/v3.3.0.tar.gz";
    hash = "sha256-TPEqV8uHbnyphLG0A+b2tgLDQ6K7a2dOuDHlaFPzTeE=";
  };

  # unordered_dense - Fast hash map
  unordered-dense = pkgs.fetchzip {
    url = "https://github.com/martinus/unordered_dense/archive/refs/tags/v4.8.1.tar.gz";
    hash = "sha256-JdPlyShWnAcdgixDHRaroFg7YWdPtD4Nl1PmpcQ1SAk=";
  };

  # gamemode - Feral game optimizations (headers only)
  gamemode = pkgs.fetchzip {
    url = "https://github.com/FeralInteractive/gamemode/archive/ce6fe122f3.tar.gz";
    hash = "sha256-RMi4PBKqx1kdthKPs8x7GZyvIapo8PXDeMoT4QCxiws=";
  };

  # vulkan-utility-libraries (custom build)
  vulkan-utility-libraries = pkgs.fetchurl {
    url = "https://git.crueter.xyz/scripts/VulkanUtilityHeaders/releases/download/1.4.328/VulkanUtilityHeaders.tar.zst";
    hash = "sha256-+BRjMR2AOHTjrvIgLl1uCOZI+keOdkY1GkVSQTrLwXQ=";
  };

  # frozen - header-only constexpr containers
  frozen = pkgs.fetchzip {
    url = "https://github.com/serge-sans-paille/frozen/archive/61dce5ae18.tar.gz";
    hash = "sha256-zIczBSRDWjX9hcmYWYkbWY3NAAQwQtKhMTeHlYp4BKk=";
  };

  # quazip - Qt ZIP library
  quazip = pkgs.fetchzip {
    url = "https://github.com/crueter/quazip-qt6/archive/f838774d63.tar.gz";
    hash = "sha256-Jp+v7uwoPxvarzOclgSnoGcwAPXKnm23yrZKtjJCHro=";
  };

  # mcl - utility library (azahar-emu)
  mcl = pkgs.fetchzip {
    url = "https://github.com/azahar-emu/mcl/archive/7b08d83418.tar.gz";
    hash = "sha256-uTOiOlMzKbZSjKjtVSqFU+9m8v8horoCq3wL0O2E8sI=";
  };

  # libusb
  libusb = pkgs.fetchzip {
    url = "https://github.com/libusb/libusb/archive/refs/tags/v1.0.29.tar.gz";
    hash = "sha256-m1w+uF8+2WCn72LvoaGUYa+R0PyXHtFFONQjdRfImYY=";
  };

  # nx_tzdb - Nintendo Switch timezone database
  nx-tzdb = pkgs.fetchurl {
    url = "https://git.crueter.xyz/misc/tzdb_to_nx/releases/download/121125/121125.tar.gz";
    hash = "sha256-wX3BUywYcZFVrOQk8VhByd/GY2gb/sawC7ft2IRC/wI=";
  };

  # oaknut - ARM64 JIT assembler (for ARM builds)
  oaknut = pkgs.fetchzip {
    url = "https://github.com/merryhime/oaknut/archive/refs/tags/2.0.2.tar.gz";
    hash = "sha256-kXqBVTmsFeC2jaN2uUq1I8ClJzhjN4HHNeChd+E62k0=";
  };

  # httplib - HTTP library (needed by qt_common) - v0.28.0
  httplib = pkgs.fetchzip {
    url = "https://github.com/yhirose/cpp-httplib/archive/refs/tags/v0.28.0.tar.gz";
    hash = "sha256-uhVmIgSnx/FfW6JfoY5YUhYFg61vZzN5E2JQSt/xHcY=";
  };

  # cpp-jwt - JWT library (crueter fork)
  cpp-jwt = pkgs.fetchzip {
    url = "https://github.com/crueter/cpp-jwt/archive/9eaea6328f.tar.gz";
    hash = "sha256-r4Kf7k0tfDzrFSCS6f8bmEAmzctXsMBSd+t9xlqfvNs=";
  };
}
