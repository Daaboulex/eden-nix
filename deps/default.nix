# Eden Emulator CPM Dependencies
# These are pre-fetched to work with Nix's sandboxed builds
# URLs and versions from Eden master cpmfile.json
{ pkgs }:

{
  # xbyak - JIT assembler for x86/x86_64
  xbyak = pkgs.fetchzip {
    url = "https://github.com/herumi/xbyak/archive/refs/tags/v7.33.2.tar.gz";
    hash = "sha256-7HFvZ6wr7X7K5rrw9k/LWXEazJ67Hm8IqO2edcEU1pI=";
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
    url = "https://github.com/eden-emulator/discord-rpc/archive/0d8b2d6a37.tar.gz";
    hash = "sha256-bsVW2yKgTyIPDyVLKYHxlllLhcY9H5B81+23zJLBIBY=";
  };

  # spirv-headers - SPIR-V headers
  spirv-headers = pkgs.fetchzip {
    url = "https://github.com/KhronosGroup/SPIRV-Headers/archive/04f10f650d.tar.gz";
    hash = "sha256-aYKFJxRDoY/Cor8gYVoR/YSyXWSNtcRG0HK8BZH0Ztk=";
  };

  # spirv-tools - SPIR-V tools
  spirv-tools = pkgs.fetchzip {
    url = "https://github.com/KhronosGroup/SPIRV-Tools/archive/0a7e28689a.tar.gz";
    hash = "sha256-yCWooy1XOIWc9PyzfpNxOg/Fja2z+TTK9Ok6PUfsRe0=";
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
    url = "https://github.com/martinus/unordered_dense/archive/7b55cab841.tar.gz";
    hash = "sha256-yCdn3/OIGLH5uW6BgvfbxPYwtiWivOHabfxaYrQromE=";
  };

  # gamemode - Feral game optimizations (headers only)
  gamemode = pkgs.fetchzip {
    url = "https://github.com/FeralInteractive/gamemode/archive/ce6fe122f3.tar.gz";
    hash = "sha256-RMi4PBKqx1kdthKPs8x7GZyvIapo8PXDeMoT4QCxiws=";
  };

  # vulkan-headers - Vulkan API headers (bundled to match vulkan-utility-libraries)
  vulkan-headers = pkgs.fetchzip {
    url = "https://github.com/KhronosGroup/Vulkan-Headers/archive/refs/tags/v1.4.342.tar.gz";
    hash = "sha256-keE8NmUG4UsDwb3vn7IB95Oo576ziH70n8fbrQx/6HA=";
  };

  # vulkan-utility-libraries - Vulkan utility libraries
  vulkan-utility-libraries = pkgs.fetchzip {
    url = "https://github.com/KhronosGroup/Vulkan-Utility-Libraries/archive/refs/tags/v1.4.342.tar.gz";
    hash = "sha256-M26HqTsnXa3Hm7H+asT7MTC/Z448J0BusegZnaXXCDo=";
  };

  # frozen - header-only constexpr containers
  frozen = pkgs.fetchzip {
    url = "https://github.com/serge-sans-paille/frozen/archive/61dce5ae18.tar.gz";
    hash = "sha256-zIczBSRDWjX9hcmYWYkbWY3NAAQwQtKhMTeHlYp4BKk=";
  };

  # quazip - Qt ZIP library (now from stachenov/quazip)
  quazip = pkgs.fetchzip {
    url = "https://github.com/stachenov/quazip/archive/2e95c9001b.tar.gz";
    hash = "sha256-F2bPhBNRNcG6qQTlHbEkdTSKEXXTNubIS1+13nBNSU8=";
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
    url = "https://github.com/eden-emulator/oaknut/archive/refs/tags/v2.0.3.tar.gz";
    hash = "sha256-NWJMottKMiG6Rk2/ACNtBiYfWDsCeSGznPTqVO809P0=";
  };

  # httplib - HTTP library (needed by qt_common)
  httplib = pkgs.fetchzip {
    url = "https://github.com/yhirose/cpp-httplib/archive/refs/tags/v0.30.1.tar.gz";
    hash = "sha256-5q77ersAJnPPpVChvntnqEly1/ek2KfX2iukTPUbKHc=";
  };

  # cpp-jwt - JWT library
  cpp-jwt = pkgs.fetchzip {
    url = "https://github.com/arun11299/cpp-jwt/archive/7f24eb4c32.tar.gz";
    hash = "sha256-qYgUTWKJAXDhDgkt3Y00QPyIkCalyZFH+dbF17CZGnE=";
  };
}
