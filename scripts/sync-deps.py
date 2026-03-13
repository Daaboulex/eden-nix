#!/usr/bin/env python3
"""Synchronize eden-nix CPM dependencies with upstream cpmfile.json.

Compares upstream cpmfile.json against local deps/default.nix and package.nix,
updates changed dependencies (URL + hash atomically), detects new/removed deps,
and checks for CMakeLists.txt system dependency changes.

Exit codes:
  0 = success (updates applied or nothing to do)
  1 = error (hash prefetch failed, file parse error)
  2 = new deps detected that need manual addition
"""

import json
import os
import re
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent

# ---------------------------------------------------------------------------
# Configuration — maps cpmfile.json structure to Nix packaging details
# ---------------------------------------------------------------------------

# cpmfile.json keys to skip entirely (not needed for our Linux desktop build)
SKIP_KEYS = {
    "libadrenotools",    # Android GPU driver loading
    "oboe",              # Android audio backend
    "catch2",            # Test framework (YUZU_TESTS=OFF)
    "biscuit",           # RISC-V JIT assembler
    "sdl2",              # CI-only prebuilt entry
    "sdl2_generic",      # We use system SDL2
    "sdl2_steamdeck",    # Steam Deck specific SDL2
    "ffmpeg",            # We use system ffmpeg
    "ffmpeg-ci",         # CI-only prebuilt entry
    "moltenvk",          # macOS Vulkan translation
    "sirit-ci",          # CI-only prebuilt entry
}

# Nix attribute name overrides (cpmfile key -> attr in deps/default.nix)
# Default: use the cpmfile key as-is
NIX_ATTR_MAP = {
    "vulkan-memory-allocator": "vma",
    "tzdb": "nx-tzdb",
}

# CPM cache directory overrides (cpmfile key -> dir name in package.nix)
# Default: lowercase of the 'package' field (or key if no package field)
CPM_DIR_MAP = {
    "discord-rpc": "discordrpc",
    "vulkan-memory-allocator": "vulkanmemoryallocator",
    "unordered-dense": "unordered_dense",
    "vulkan-headers": "vulkanheaders",
    "vulkan-utility-libraries": "vulkanutilitylibraries",
    "spirv-headers": "spirv-headers",
    "spirv-tools": "spirv-tools",
    "tzdb": "nx_tzdb",
    "cpp-jwt": "cpp-jwt",
    "quazip": "quazip-qt6",
}

# Platform restrictions for package.nix (cpmfile key -> platform)
PLATFORMS = {
    "xbyak": "x86_64",
    "oaknut": "aarch64",
}

# Deps that use extractDep (fetchurl archives) instead of copyDep (fetchzip dirs)
EXTRACT_DEPS = {"sirit", "mbedtls", "nx-tzdb"}

# Extra deps NOT in cpmfile.json (managed via GitHub releases API)
EXTRA_DEPS = {
    "mbedtls": {
        "github_repo": "Mbed-TLS/mbedtls",
        "tag_prefix": "mbedtls-",
        "url_template": "https://github.com/Mbed-TLS/mbedtls/releases/download/mbedtls-{version}/mbedtls-{version}.tar.bz2",
        "fetch_type": "fetchurl",
        "cpm_dir": "mbedtls",
    },
    "quazip": {
        "github_repo": "stachenov/quazip",
        "fetch_type": "fetchzip_commit",
        "cpm_dir": "quazip-qt6",
    },
}

# Known system dependencies (buildInputs/nativeBuildInputs) mapped from
# CMake find_package() names to nixpkgs attribute names.
# Used to detect when upstream adds new system deps.
CMAKE_TO_NIX = {
    "Boost": "boost",
    "FFmpeg": "ffmpeg",
    "fmt": "fmt",
    "lz4": "lz4",
    "nlohmann_json": "nlohmann_json",
    "OpenSSL": "openssl",
    "SDL2": "SDL2",
    "ZLIB": "zlib",
    "zstd": "zstd",
    "Opus": "libopus",
    "LibUSB": "libusb1",
    "PkgConfig": "pkg-config",
    "Protobuf": "protobuf",
    "Vulkan": "vulkan-loader",
    "Qt6": "qt6Packages",
    "VAAPI": "libva",
    "CUDA": None,  # not packaged
}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def get_nix_attr(cpm_key: str) -> str:
    """Get the Nix attribute name for a cpmfile.json key."""
    return NIX_ATTR_MAP.get(cpm_key, cpm_key)


def get_cpm_dir(cpm_key: str, entry: dict) -> str:
    """Get the CPM cache directory name for a dep."""
    if cpm_key in CPM_DIR_MAP:
        return CPM_DIR_MAP[cpm_key]
    # Default: lowercase of 'package' field, or the key itself
    pkg = entry.get("package", cpm_key)
    return pkg.lower()


def get_cpm_version(cpm_key: str, entry: dict) -> str | None:
    """Get the version string used in CPM cache paths."""
    if "git_version" in entry:
        return entry["git_version"]
    if "sha" in entry:
        return entry["sha"][:4]
    if "version" in entry:
        return entry["version"]
    return None


def resolve_url(cpm_key: str, entry: dict) -> tuple[str, str] | None:
    """Resolve the fetch URL and type ('fetchzip' or 'fetchurl') for a dep.

    Returns (url, fetch_type) or None if unresolvable.
    """
    repo = entry.get("repo", "")
    host = entry.get("git_host", None)

    if "artifact" in entry:
        # Release artifact download (fetchurl)
        ver = entry.get("git_version", entry.get("version", ""))
        tag_pattern = entry.get("tag", "v%VERSION%")
        tag = tag_pattern.replace("%VERSION%", ver)
        artifact = entry["artifact"].replace("%VERSION%", ver)
        if host:
            url = f"https://{host}/{repo}/releases/download/{tag}/{artifact}"
        else:
            url = f"https://github.com/{repo}/releases/download/{tag}/{artifact}"
        return (url, "fetchurl")

    elif "tag" in entry and "git_version" in entry:
        # Tag-based release (fetchzip)
        ver = entry["git_version"]
        tag = entry["tag"].replace("%VERSION%", ver)
        return (f"https://github.com/{repo}/archive/refs/tags/{tag}.tar.gz", "fetchzip")

    elif "sha" in entry:
        # Commit-based (fetchzip)
        return (f"https://github.com/{repo}/archive/{entry['sha']}.tar.gz", "fetchzip")

    return None


def nix_prefetch(url: str, unpack: bool = True) -> str | None:
    """Compute SRI hash for a URL using nix-prefetch-url."""
    cmd = ["nix-prefetch-url"]
    if unpack:
        cmd.append("--unpack")
    cmd.append(url)

    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=600)
        if result.returncode != 0:
            print(f"  nix-prefetch-url failed: {result.stderr.strip()}", file=sys.stderr)
            return None
        base32_hash = result.stdout.strip()

        # Convert base32 -> SRI
        result2 = subprocess.run(
            ["nix", "hash", "convert", "--hash-algo", "sha256", "--to", "sri", base32_hash],
            capture_output=True, text=True,
        )
        if result2.returncode != 0:
            return None
        return result2.stdout.strip()
    except (subprocess.TimeoutExpired, FileNotFoundError) as e:
        print(f"  Hash computation error: {e}", file=sys.stderr)
        return None


# ---------------------------------------------------------------------------
# File parsing
# ---------------------------------------------------------------------------

def parse_deps_nix(path: Path) -> dict[str, dict]:
    """Parse deps/default.nix to extract current dep URLs and hashes.

    Returns {attr_name: {"url": str, "hash": str, "fetch_type": str}}.
    """
    content = path.read_text()
    deps = {}

    # Match: attr = pkgs.fetchzip { url = "..."; hash = "..."; };
    # or:    attr = pkgs.fetchurl { url = "..."; hash = "..."; };
    pattern = re.compile(
        r'([\w-]+)\s*=\s*pkgs\.(fetchzip|fetchurl)\s*\{([^}]+)\}',
        re.DOTALL,
    )

    for m in pattern.finditer(content):
        attr = m.group(1)
        fetch_type = m.group(2)
        block = m.group(3)

        url_match = re.search(r'url\s*=\s*"([^"]+)"', block)
        hash_match = re.search(r'hash\s*=\s*"([^"]+)"', block)

        deps[attr] = {
            "fetch_type": fetch_type,
            "url": url_match.group(1) if url_match else "",
            "hash": hash_match.group(1) if hash_match else "",
        }

    return deps


def parse_cpm_paths(path: Path) -> dict[str, tuple[str, str]]:
    """Parse package.nix preConfigure to extract CPM cache paths.

    Returns {nix_attr: (cpm_dir, version)}.
    E.g., {"xbyak": ("xbyak", "7.35.2"), "cubeb": ("cubeb", "fa02")}
    """
    content = path.read_text()
    paths = {}

    # Match: copyDep ${deps.attr} dir/version  or  extractDep ${deps.attr} dir/version
    pattern = re.compile(r'(?:copyDep|extractDep)\s+\$\{deps\.([\w-]+)\}\s+([\w._-]+)/([\w._-]+)')
    for m in pattern.finditer(content):
        attr = m.group(1)
        cpm_dir = m.group(2)
        version = m.group(3)
        paths[attr] = (cpm_dir, version)

    return paths


# ---------------------------------------------------------------------------
# File updating
# ---------------------------------------------------------------------------

def update_dep_in_deps_nix(path: Path, attr: str, new_url: str, new_hash: str) -> bool:
    """Update URL and hash for a dep in deps/default.nix atomically."""
    content = path.read_text()

    # Find the block for this attribute and update both url and hash together
    # This ensures they can never desync
    block_pattern = re.compile(
        rf'({re.escape(attr)}\s*=\s*pkgs\.(?:fetchzip|fetchurl)\s*\{{[^}}]*?)'
        rf'url\s*=\s*"[^"]*"'
        rf'([^}}]*?)'
        rf'hash\s*=\s*"[^"]*"',
        re.DOTALL,
    )

    match = block_pattern.search(content)
    if not match:
        print(f"  WARNING: Could not find {attr} block in deps/default.nix", file=sys.stderr)
        return False

    new_content = (
        content[:match.start()]
        + f'{match.group(1)}url = "{new_url}"{match.group(2)}hash = "{new_hash}"'
        + content[match.end():]
    )

    path.write_text(new_content)
    return True


def update_cpm_path(path: Path, nix_attr: str, cpm_dir: str, old_ver: str, new_ver: str) -> bool:
    """Update CPM cache path version in package.nix."""
    content = path.read_text()

    # Match the specific copyDep/extractDep line for this attr
    pattern = re.compile(
        rf'((?:copyDep|extractDep)\s+\${{deps\.{re.escape(nix_attr)}}}\s+){re.escape(cpm_dir)}/{re.escape(old_ver)}'
    )

    new_content = pattern.sub(rf'\g<1>{cpm_dir}/{new_ver}', content)

    if new_content == content:
        print(f"  WARNING: Could not update CPM path for {nix_attr} ({cpm_dir}/{old_ver} -> {new_ver})", file=sys.stderr)
        return False

    path.write_text(new_content)
    return True


def generate_dep_nix(attr: str, url: str, sri_hash: str, fetch_type: str, comment: str) -> str:
    """Generate a Nix dep entry for a new dependency."""
    return f"""
  # {comment}
  {attr} = pkgs.{fetch_type} {{
    url = "{url}";
    hash = "{sri_hash}";
  }};
"""


def generate_cpm_line(nix_attr: str, cpm_dir: str, version: str, is_extract: bool) -> str:
    """Generate a copyDep/extractDep line for package.nix."""
    fn = "extractDep" if is_extract else "copyDep"
    return f'    {fn} ${{deps.{nix_attr}}} {cpm_dir}/{version}'


# ---------------------------------------------------------------------------
# CMake system dep detection
# ---------------------------------------------------------------------------

def extract_find_packages(cmake_content: str) -> set[str]:
    """Extract find_package() names from CMakeLists.txt content."""
    pattern = re.compile(r'find_package\s*\(\s*(\w+)', re.IGNORECASE)
    return {m.group(1) for m in pattern.finditer(cmake_content)}


def check_cmake_changes(old_commit: str, new_commit: str) -> list[str]:
    """Detect new find_package() calls between two commits.

    Returns list of warning strings for new system deps.
    """
    warnings = []

    base_url = "https://git.eden-emu.dev/eden-emu/eden/raw/commit"
    cmake_file = "CMakeLists.txt"

    for path in [cmake_file, "src/CMakeLists.txt"]:
        try:
            old_resp = subprocess.run(
                ["curl", "-sf", f"{base_url}/{old_commit}/{path}"],
                capture_output=True, text=True, timeout=30,
            )
            new_resp = subprocess.run(
                ["curl", "-sf", f"{base_url}/{new_commit}/{path}"],
                capture_output=True, text=True, timeout=30,
            )

            if old_resp.returncode != 0 or new_resp.returncode != 0:
                continue

            old_pkgs = extract_find_packages(old_resp.stdout)
            new_pkgs = extract_find_packages(new_resp.stdout)
            added = new_pkgs - old_pkgs

            for pkg in sorted(added):
                nix_pkg = CMAKE_TO_NIX.get(pkg)
                if nix_pkg is None and pkg not in CMAKE_TO_NIX:
                    warnings.append(
                        f"NEW SYSTEM DEP: find_package({pkg}) added in {path} "
                        f"— needs manual addition to package.nix buildInputs"
                    )
                elif nix_pkg and nix_pkg not in ("pkg-config",):
                    warnings.append(
                        f"NEW SYSTEM DEP: find_package({pkg}) added in {path} "
                        f"— add '{nix_pkg}' to package.nix buildInputs"
                    )

        except (subprocess.TimeoutExpired, Exception):
            continue

    return warnings


# ---------------------------------------------------------------------------
# Main sync logic
# ---------------------------------------------------------------------------

def main() -> int:
    if len(sys.argv) < 2:
        print(f"Usage: {sys.argv[0]} <cpmfile.json> [old_commit new_commit]", file=sys.stderr)
        return 1

    cpmfile_path = Path(sys.argv[1])
    cpmfile = json.loads(cpmfile_path.read_text())

    old_commit = sys.argv[2] if len(sys.argv) > 2 else None
    new_commit = sys.argv[3] if len(sys.argv) > 3 else None

    deps_nix_path = REPO_ROOT / "deps" / "default.nix"
    package_nix_path = REPO_ROOT / "package.nix"

    current_deps = parse_deps_nix(deps_nix_path)
    current_cpm_paths = parse_cpm_paths(package_nix_path)

    updated = []
    warnings = []
    errors = []
    new_dep_suggestions = []

    # --- Process each cpmfile.json entry ---
    for cpm_key, entry in cpmfile.items():
        # Skip CI-only, platform-excluded, explicitly skipped
        if cpm_key in SKIP_KEYS:
            continue
        if entry.get("ci"):
            continue
        if entry.get("skip_updates") == True or entry.get("skip_updates") == "true":
            continue

        nix_attr = get_nix_attr(cpm_key)

        # Check if we currently track this dep
        if nix_attr not in current_deps:
            # New dep — generate suggestion
            resolved = resolve_url(cpm_key, entry)
            if resolved:
                url, fetch_type = resolved
                cpm_dir = get_cpm_dir(cpm_key, entry)
                cpm_ver = get_cpm_version(cpm_key, entry)
                is_extract = fetch_type == "fetchurl"

                new_dep_suggestions.append({
                    "key": cpm_key,
                    "attr": nix_attr,
                    "url": url,
                    "fetch_type": fetch_type,
                    "cpm_dir": cpm_dir,
                    "cpm_version": cpm_ver,
                    "is_extract": is_extract,
                })
                warnings.append(
                    f"NEW CPM DEP: '{cpm_key}' (attr: {nix_attr}) not in deps/default.nix — "
                    f"URL: {url}"
                )
            continue

        # Resolve new URL
        resolved = resolve_url(cpm_key, entry)
        if resolved is None:
            warnings.append(f"Could not resolve URL for '{cpm_key}'")
            continue

        new_url, expected_fetch_type = resolved
        cur = current_deps[nix_attr]

        # Skip if URL hasn't changed
        if cur["url"] == new_url:
            continue

        # --- URL changed — update both URL and hash atomically ---
        old_ver = current_cpm_paths.get(nix_attr, (None, None))[1]
        new_ver = get_cpm_version(cpm_key, entry)
        cpm_dir = get_cpm_dir(cpm_key, entry)

        print(f"Updating {nix_attr}: {old_ver or '?'} -> {new_ver or '?'}")
        print(f"  Old URL: {cur['url']}")
        print(f"  New URL: {new_url}")

        # Compute hash (unpack for fetchzip, raw for fetchurl)
        unpack = expected_fetch_type == "fetchzip"
        new_hash = nix_prefetch(new_url, unpack=unpack)

        if new_hash is None:
            errors.append(f"Failed to prefetch hash for {nix_attr} ({new_url})")
            continue

        # Update deps/default.nix (URL + hash together)
        if not update_dep_in_deps_nix(deps_nix_path, nix_attr, new_url, new_hash):
            errors.append(f"Failed to update {nix_attr} in deps/default.nix")
            continue

        # Update CPM cache path in package.nix
        if old_ver and new_ver and old_ver != new_ver:
            if not update_cpm_path(package_nix_path, nix_attr, cpm_dir, old_ver, new_ver):
                warnings.append(f"Could not update CPM path for {nix_attr} in package.nix")

        updated.append(f"{nix_attr}: {old_ver or '?'} -> {new_ver or '?'}")

    # --- Check for removed deps ---
    # Build set of nix attrs that cpmfile.json accounts for
    cpmfile_attrs = set()
    for cpm_key in cpmfile:
        if cpm_key not in SKIP_KEYS and not cpmfile[cpm_key].get("ci"):
            cpmfile_attrs.add(get_nix_attr(cpm_key))

    extra_dep_attrs = set(EXTRA_DEPS.keys())

    for attr in current_deps:
        if attr not in cpmfile_attrs and attr not in extra_dep_attrs:
            warnings.append(
                f"POSSIBLY REMOVED: '{attr}' is in deps/default.nix but not in "
                f"cpmfile.json — verify it's still needed"
            )

    # --- Check for CMake system dep changes ---
    if old_commit and new_commit:
        cmake_warnings = check_cmake_changes(old_commit, new_commit)
        warnings.extend(cmake_warnings)

    # --- Report ---
    print()
    if updated:
        print(f"Updated {len(updated)} dependencies:")
        for u in updated:
            print(f"  {u}")

    if new_dep_suggestions:
        print(f"\n{len(new_dep_suggestions)} new dependencies need manual addition:")
        for s in new_dep_suggestions:
            print(f"\n  # Add to deps/default.nix:")
            print(f"  {generate_dep_nix(s['attr'], s['url'], '<HASH>', s['fetch_type'], s['key']).strip()}")
            print(f"\n  # Add to package.nix preConfigure:")
            print(f"  {generate_cpm_line(s['attr'], s['cpm_dir'], s['cpm_version'] or '?', s['is_extract']).strip()}")

    if warnings:
        print(f"\nWarnings ({len(warnings)}):")
        for w in warnings:
            print(f"  {w}")

    if errors:
        print(f"\nErrors ({len(errors)}):")
        for e in errors:
            print(f"  {e}")

    # Write structured output for workflow consumption
    output = {
        "updated": updated,
        "warnings": warnings,
        "errors": errors,
        "new_deps": [s["key"] for s in new_dep_suggestions],
    }
    output_path = REPO_ROOT / ".sync-output.json"
    output_path.write_text(json.dumps(output, indent=2))

    if errors:
        return 1
    if new_dep_suggestions:
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
