#!/bin/bash
set -e

GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/build"

echo "=== Cleaning build directory ==="
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR/windows" "$BUILD_DIR/linux" "$BUILD_DIR/macos"

echo "=== Importing project ==="
"$GODOT" --headless --path "$PROJECT_DIR" --import 2>&1 || true

for preset in "Windows" "Linux" "macOS"; do
    echo "=== Exporting $preset ==="
    "$GODOT" --headless --path "$PROJECT_DIR" --export-release "$preset" 2>&1
done

echo "=== Zipping builds ==="
for platform in windows linux macos; do
    (cd "$BUILD_DIR/$platform" && zip -r "$BUILD_DIR/ElderScrollsLegends-$platform.zip" .)
done

echo "=== Done ==="
ls -lh "$BUILD_DIR"/*.zip
