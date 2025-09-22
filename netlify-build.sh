#!/bin/bash
set -e  # Exit immediately if a command fails

# Log start
echo "=== Netlify Flutter Web Build Starting ==="

# Ensure Flutter is available
if ! command -v flutter &> /dev/null; then
    echo "Flutter not found. Installing Flutter..."
    git clone https://github.com/flutter/flutter.git -b stable /opt/flutter
    export PATH="$PATH:/opt/flutter/bin"
fi

# Confirm Flutter version
flutter --version

# Navigate to project root (adjust if your Flutter project is in a subfolder)
PROJECT_ROOT=$(pwd)
echo "Project root: $PROJECT_ROOT"

# Get Flutter dependencies
echo "Running flutter pub get..."
flutter pub get

# Build Flutter web
echo "Building Flutter web..."
flutter build web --release

# Optional: specify output folder for Netlify
echo "Build completed. Output folder: build/web"

echo "=== Netlify Flutter Web Build Finished ==="
