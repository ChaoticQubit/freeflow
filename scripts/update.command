#!/bin/bash
#
# FreeFlow — local update script.
#
# Pull upstream changes from GitHub, rebuild the app with the local
# preserve-exact-wording toggle patch intact, and install to
# /Applications/FreeFlow.app.
#
# Safe to double-click from Finder or run from Terminal. If any step
# fails the script stops and prints an explanation.

set -euo pipefail

# Resolve the repo root as the parent of this script's directory, so the
# script works whether launched via a symlink, from Finder, or from
# another cwd.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

APP_NAME="FreeFlow"
BUNDLE_ID="com.zachlatta.freeflow"
INSTALL_PATH="/Applications/${APP_NAME}.app"
BUILT_APP="${REPO_ROOT}/build/${APP_NAME}.app"

# Codesign identity: ad-hoc (-) because this machine has no Developer ID.
CODESIGN_IDENTITY="${CODESIGN_IDENTITY:--}"

log()  { printf '\n\033[1;34m▶ %s\033[0m\n' "$*"; }
warn() { printf '\n\033[1;33m⚠ %s\033[0m\n' "$*"; }
die()  { printf '\n\033[1;31m✘ %s\033[0m\n' "$*" >&2; exit 1; }

cd "$REPO_ROOT"

log "Repository: $REPO_ROOT"

# --- Preflight -------------------------------------------------------

command -v git   >/dev/null 2>&1 || die "git not found on PATH"
command -v make  >/dev/null 2>&1 || die "make not found on PATH"
command -v xcrun >/dev/null 2>&1 || die "xcrun not found on PATH (Xcode command line tools required)"

# --- Pull upstream ---------------------------------------------------

log "Fetching upstream changes"
git fetch --tags origin

CURRENT_BRANCH="$(git rev-parse --abbrev-ref HEAD)"
log "Current branch: $CURRENT_BRANCH"

# Rebase local commits (which include the preserve-exact-wording patch)
# on top of upstream so the toggle keeps working after upgrade. If the
# rebase hits a conflict, abort cleanly and tell the user.
if ! git pull --rebase --autostash origin "$CURRENT_BRANCH"; then
    warn "git rebase failed — aborting and leaving the working tree untouched"
    git rebase --abort >/dev/null 2>&1 || true
    die "Please resolve conflicts manually in $REPO_ROOT, then re-run this script"
fi

# --- Rebuild ---------------------------------------------------------

log "Building ${APP_NAME}.app (this can take a minute)"
rm -rf build
CODESIGN_IDENTITY="$CODESIGN_IDENTITY" \
    make APP_NAME="$APP_NAME" BUNDLE_ID="$BUNDLE_ID"

[ -d "$BUILT_APP" ] || die "Build finished but $BUILT_APP does not exist"

# --- Install ---------------------------------------------------------

log "Installing to $INSTALL_PATH"

# Kill any running instance so cp -R doesn't hit "Text file busy".
pkill -x "$APP_NAME" >/dev/null 2>&1 || true
sleep 1

rm -rf "$INSTALL_PATH"
cp -R "$BUILT_APP" "$INSTALL_PATH"

# Strip macOS quarantine so Gatekeeper doesn't complain on first launch.
xattr -dr com.apple.quarantine "$INSTALL_PATH" 2>/dev/null || true

log "Relaunching ${APP_NAME}"
open "$INSTALL_PATH"

INSTALLED_VERSION="$(defaults read "$INSTALL_PATH/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo unknown)"

printf '\n\033[1;32m✔ ${APP_NAME} updated to version %s\033[0m\n' "$INSTALLED_VERSION"
printf '\nYou can close this window.\n'
