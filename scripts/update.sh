#!/usr/bin/env bash
set -euo pipefail

OUTPUT_FILE="${GITHUB_OUTPUT:-/tmp/update-outputs.env}"
: >"$OUTPUT_FILE"
output() { echo "$1=$2" >>"$OUTPUT_FILE"; }
log() { echo "==> $*"; }
warn() { echo "::warning::$*"; }
err() { echo "::error::$*"; }

CONFIG=$(cat .github/update.json)
HOST=$(echo "$CONFIG" | jq -r '.upstream.host')
OWNER=$(echo "$CONFIG" | jq -r '.upstream.owner')
REPO=$(echo "$CONFIG" | jq -r '.upstream.repo')
BRANCH=$(echo "$CONFIG" | jq -r '.upstream.branch // "master"')
PACKAGE=$(echo "$CONFIG" | jq -r '.package')
output "package_name" "$PACKAGE"
output "upstream_url" "https://$HOST/$OWNER/$REPO"

CURRENT_REV=$(grep -oP 'rev\s*=\s*"\K[0-9a-f]+' package.nix | head -1 || true)
CURRENT_VERSION=$(grep -oP 'version\s*=\s*"\K[^"]+' package.nix | head -1 || true)
CURRENT_HASH=$(grep -oP 'hash\s*=\s*"\Ksha256-[^"]+' package.nix | head -1 || true)
if [ -z "$CURRENT_REV" ] || [ -z "$CURRENT_VERSION" ] || [ -z "$CURRENT_HASH" ]; then
  err "Could not read current rev/version/hash from package.nix"
  output "updated" "false"
  output "error_type" "version-read"
  exit 1
fi
output "old_version" "$CURRENT_VERSION"
log "Current: $CURRENT_VERSION ($CURRENT_REV)"

API="https://$HOST/api/v1/repos/$OWNER/$REPO/branches/$BRANCH"
BRANCH_JSON=$(curl -sfL --retry 3 --retry-all-errors "$API" 2>/dev/null) || {
  warn "Failed to reach Gitea API: $API"
  output "updated" "false"
  exit 2
}
NEW_REV=$(echo "$BRANCH_JSON" | jq -r '.commit.id // empty')
NEW_DATE=$(echo "$BRANCH_JSON" | jq -r '.commit.timestamp // empty' | cut -dT -f1)
if [ -z "$NEW_REV" ] || [ -z "$NEW_DATE" ]; then
  warn "Gitea API response missing commit id / timestamp"
  output "updated" "false"
  exit 2
fi

if [ "$NEW_REV" = "$CURRENT_REV" ]; then
  log "Already up to date ($CURRENT_REV)"
  output "updated" "false"
  exit 0
fi

BASE="${CURRENT_VERSION%%-unstable-*}"
NEW_VERSION="${BASE}-unstable-${NEW_DATE}"
output "new_version" "$NEW_VERSION"
output "updated" "true"
log "Update: $CURRENT_REV -> $NEW_REV  ($CURRENT_VERSION -> $NEW_VERSION)"

sed -i "s|rev = \"${CURRENT_REV}\"|rev = \"${NEW_REV}\"|" package.nix
sed -i "s|version = \"${CURRENT_VERSION}\"|version = \"${NEW_VERSION}\"|" package.nix

MANIFEST_URL="https://$HOST/$OWNER/$REPO/raw/commit/$NEW_REV/cpmfile.json"
if ! curl -sfL --retry 3 --retry-all-errors "$MANIFEST_URL" -o deps/cpmfile.json ||
  ! jq -e 'type == "object"' deps/cpmfile.json >/dev/null; then
  err "Could not fetch a JSON object from $MANIFEST_URL"
  output "error_type" "cpmfile-fetch"
  exit 1
fi
log "Vendored cpmfile.json at $NEW_REV ($(jq 'keys | length' deps/cpmfile.json) entries)"

DUMMY_HASH="sha256-AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
sed -i "s|hash = \"${CURRENT_HASH}\"|hash = \"${DUMMY_HASH}\"|" package.nix
BUILD_OUTPUT=$(nix build .#default --no-link 2>&1 || true)
NEW_HASH=$(echo "$BUILD_OUTPUT" | grep -oP 'got:\s+\Ksha256-\S+' | head -1 || true)
if [ -z "$NEW_HASH" ]; then
  err "Could not extract the eden source hash from the build output"
  output "error_type" "hash-extraction"
  exit 1
fi
MISMATCH_COUNT=$(echo "$BUILD_OUTPUT" | grep -c 'hash mismatch in fixed-output' || true)
if [ "$MISMATCH_COUNT" -gt 1 ]; then
  err "More than one fixed-output hash mismatched: a cpmfile.json hash disagrees with its archive; manual review needed"
  output "error_type" "cpm-deps-drift"
  exit 1
fi
sed -i "s|hash = \"${DUMMY_HASH}\"|hash = \"${NEW_HASH}\"|" package.nix
log "eden source hash: $NEW_HASH"

log "Step 1/2: nix flake check --no-build"
if ! nix flake check --no-build 2>&1; then
  err "Eval check failed"
  output "error_type" "eval-error"
  exit 1
fi

log "Step 2/2: nix build (full)"
if ! nix build .#default --no-link --print-build-logs 2>&1; then
  err "Build failed at $NEW_VERSION"
  output "error_type" "build-error"
  exit 1
fi

log "Update verified: $CURRENT_VERSION -> $NEW_VERSION"
exit 0
