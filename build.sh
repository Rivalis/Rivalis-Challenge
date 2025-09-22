#!/bin/bash
set -e

# Clone Flutter if it doesn't exist
if [ ! -d "flutter" ]; then
  git clone https://github.com/flutter/flutter.git -b stable --depth 1
fi

# Add Flutter to PATH
export PATH="$PWD/flutter/bin:$PATH"

# Enable web support
flutter config --enable-web

# Get dependencies
flutter pub get

# Build the web project
flutter build web --release
