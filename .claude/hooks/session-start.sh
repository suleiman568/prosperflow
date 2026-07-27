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

# Locate an existing Flutter (PATH or a known cached location), else install one.
flutter_bin=""
if command -v flutter >/dev/null 2>&1; then
  flutter_bin="$(dirname "$(command -v flutter)")"
else
  for d in "$INSTALL_DIR" /tmp/claude-0/flutter /opt/flutter /usr/local/flutter; do
    if [ -x "$d/bin/flutter" ]; then
      flutter_bin="$d/bin"
      break
    fi
  done
fi

if [ -z "$flutter_bin" ]; then
  echo "Installing Flutter $FLUTTER_VERSION ..."
  git clone --depth 1 --branch "$FLUTTER_VERSION" \
    https://github.com/flutter/flutter.git "$INSTALL_DIR"
  flutter_bin="$INSTALL_DIR/bin"
fi

export PATH="$flutter_bin:$PATH"

# Persist Flutter on PATH for the rest of the session.
if [ -n "${CLAUDE_ENV_FILE:-}" ]; then
  echo "export PATH=\"$flutter_bin:\$PATH\"" >> "$CLAUDE_ENV_FILE"
fi

# Warm the toolchain (first run downloads the Dart SDK + artifacts) and fetch deps.
flutter --version
flutter pub get
