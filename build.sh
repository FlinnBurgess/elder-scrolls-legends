#!/bin/bash
set -e

GODOT="/Applications/Godot.app/Contents/MacOS/Godot"
PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="$PROJECT_DIR/build"

# Parse args or prompt interactively
PLATFORMS=()
if [[ $# -gt 0 ]]; then
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --platform)
                shift
                case "$1" in
                    windows) PLATFORMS+=("windows") ;;
                    macos)   PLATFORMS+=("macos") ;;
                    linux)   PLATFORMS+=("linux") ;;
                    *)       echo "Unknown platform: $1"; exit 1 ;;
                esac
                shift
                ;;
            *) echo "Unknown option: $1"; exit 1 ;;
        esac
    done
else
    read -r -p "Platform? [w]indows / [l]inux / [m]acos / [enter] all: " choice
    case "$choice" in
        w) PLATFORMS+=("windows") ;;
        l) PLATFORMS+=("linux") ;;
        m) PLATFORMS+=("macos") ;;
        *) PLATFORMS=("windows" "linux" "macos") ;;
    esac
fi

preset_for() {
    case "$1" in
        windows) echo "Windows" ;;
        linux)   echo "Linux" ;;
        macos)   echo "macOS" ;;
    esac
}

echo "=== Cleaning build directory ==="
for platform in "${PLATFORMS[@]}"; do
    rm -rf "$BUILD_DIR/$platform"
    mkdir -p "$BUILD_DIR/$platform"
done

echo "=== Importing project ==="
"$GODOT" --headless --path "$PROJECT_DIR" --import 2>&1 || true

for platform in "${PLATFORMS[@]}"; do
    preset="$(preset_for "$platform")"
    echo "=== Exporting $preset ==="
    "$GODOT" --headless --path "$PROJECT_DIR" --export-release "$preset" 2>&1
done

echo "=== Zipping builds ==="
for platform in "${PLATFORMS[@]}"; do
    (cd "$BUILD_DIR/$platform" && zip -r "$BUILD_DIR/ElderScrollsLegends-$platform.zip" .)
done

echo "=== Done ==="
ls -lh "$BUILD_DIR"/ElderScrollsLegends-*.zip
