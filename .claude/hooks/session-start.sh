#!/bin/bash
# SessionStart hook: make the Flutter toolchain available and fetch packages so
# `flutter test` / `flutter analyze` work immediately in Claude Code on the web.
#
# Reuses a Flutter install if the environment already has one (common on cached
# containers); otherwise clones the pinned version. Runs synchronously so the
# session never starts before the toolchain is ready.
set -euo pipefail

# Only needed in the remote (web) environment; local machines have their own SDK.
if [ "${CLAUDE_CODE_REMOTE:-}" != "true" ]; then
  exit 0
fi

# Keep in sync with the flutter-version pinned in .github/workflows/ci.yml.
FLUTTER_VERSION="3.38.5"
INSTALL_DIR="$HOME/flutter"

# True only if the Flutter at $1/flutter reports exactly the pinned version, so
# a cached SDK of a different version is never silently used (it would drift
# from CI and the format check).
version_ok() {
  "$1/flutter" --version 2>/dev/null | grep -qF "Flutter $FLUTTER_VERSION "
}

# Reuse an existing Flutter only if it's the pinned version; check PATH first,
# then our managed dir, then common cache locations.
flutter_bin=""
candidates=()
if command -v flutter >/dev/null 2>&1; then
  candidates+=("$(dirname "$(command -v flutter)")")
fi
for d in "$INSTALL_DIR" /tmp/claude-0/flutter /opt/flutter /usr/local/flutter; do
  candidates+=("$d/bin")
done
for c in "${candidates[@]}"; do
  if [ -x "$c/flutter" ] && version_ok "$c"; then
    flutter_bin="$c"
    break
  fi
done

if [ -z "$flutter_bin" ]; then
  echo "Installing Flutter $FLUTTER_VERSION ..."
  # Clone into a scratch dir and only swap it into place on success, so a
  # failed (e.g. network-interrupted) download never destroys an existing
  # install or leaves a half-populated one behind.
  tmp_dir="$(mktemp -d "${INSTALL_DIR}.XXXXXX")"
  if git clone --depth 1 --branch "$FLUTTER_VERSION" \
       https://github.com/flutter/flutter.git "$tmp_dir"; then
    rm -rf "$INSTALL_DIR"
    mv "$tmp_dir" "$INSTALL_DIR"
    flutter_bin="$INSTALL_DIR/bin"
  else
    rm -rf "$tmp_dir"
    echo "Flutter install failed; left any existing SDK untouched." >&2
    exit 1
  fi
fi

export PATH="$flutter_bin:$PATH"

# Persist Flutter on PATH for the rest of the session.
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export PATH=\"$flutter_bin:\$PATH\"" >> "$CLAUDE_ENV_FILE"
fi

# Warm the toolchain (first run downloads the Dart SDK + artifacts) and fetch deps.
flutter --version
flutter pub get
