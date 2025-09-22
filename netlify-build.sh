#!/bin/bash
set -e  # Exit immediately if a command exits with a non-zero status

echo "=== Netlify Flutter Web Build Starting ==="

# Use Netlify's pre-installed Flutter
export PATH="/opt/buildhome/flutter/bin:$PATH"

# Check Flutter version
flutter --version

# Navigate to your project root (should already be in /opt/build/repo)
echo "Running flutter pub get..."
flutter pub get

echo "Building Flutter web..."
flutter build web --release

echo "Flutter web build completed successfully!"
