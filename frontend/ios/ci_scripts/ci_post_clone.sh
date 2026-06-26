#!/bin/sh
set -e

FLUTTER_DIR="$HOME/flutter"
git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$FLUTTER_DIR"
export PATH="$PATH:$FLUTTER_DIR/bin"

"$FLUTTER_DIR/bin/flutter" precache --ios

cd "$CI_PRIMARY_REPOSITORY_PATH/frontend"
"$FLUTTER_DIR/bin/flutter" pub get
"$FLUTTER_DIR/bin/flutter" build ios --no-codesign --config-only
