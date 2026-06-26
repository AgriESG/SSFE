#!/bin/sh
set -e

# Install Flutter
git clone https://github.com/flutter/flutter.git --depth 1 -b stable "$HOME/flutter"
export PATH="$PATH:$HOME/flutter/bin"

# Pre-cache iOS tools
flutter precache --ios

# Get Flutter packages
cd "$CI_PRIMARY_REPOSITORY_PATH/frontend"
flutter pub get
