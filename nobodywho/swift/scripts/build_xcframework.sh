#!/bin/bash
set -e

# Build XCFramework for NobodyWho Swift SDK
# This script builds the Rust uniffi crate for iOS, macOS, visionOS, and watchOS,
# generates Swift bindings, and packages everything into an XCFramework.
#
# Usage:
#   ./build_xcframework.sh [OPTIONS]
#
# Options:
#   --debug                 Build debug instead of release
#   --skip-build            Skip cargo build, only recreate xcframework
#   --workspace DIR         Path to the nobodywho Cargo workspace
#                           (default: auto-detected relative to this script)
#   -h, --help              Show this help

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SWIFT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Auto-detect workspace: works both as submodule (../.. from swift/) and standalone (../nobodywho/nobodywho)
if [ -f "$SWIFT_DIR/../Cargo.toml" ] && grep -q "nobodywho-uniffi" "$SWIFT_DIR/../Cargo.toml" 2>/dev/null; then
    DEFAULT_WORKSPACE="$(cd "$SWIFT_DIR/.." && pwd)"
elif [ -f "$SWIFT_DIR/../nobodywho/nobodywho/Cargo.toml" ]; then
    DEFAULT_WORKSPACE="$(cd "$SWIFT_DIR/../nobodywho/nobodywho" && pwd)"
else
    DEFAULT_WORKSPACE="$(cd "$SWIFT_DIR/.." && pwd)"
fi

WORKSPACE_DIR="${NOBODYWHO_WORKSPACE:-$DEFAULT_WORKSPACE}"
UNIFFI_DIR="$WORKSPACE_DIR/uniffi"
TARGET_DIR="$WORKSPACE_DIR/target"
XCFRAMEWORK_OUTPUT="$SWIFT_DIR/NobodyWhoFFI.xcframework"
LIB_NAME="libnobodywho_uniffi"

# Parse arguments
BUILD_TYPE="release"
SKIP_BUILD=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --debug)
            BUILD_TYPE="debug"
            shift
            ;;
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --workspace)
            WORKSPACE_DIR="$2"
            UNIFFI_DIR="$WORKSPACE_DIR/uniffi"
            TARGET_DIR="$WORKSPACE_DIR/target"
            shift 2
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --debug             Build debug instead of release"
            echo "  --skip-build        Skip cargo build, only recreate xcframework"
            echo "  --workspace DIR     Path to nobodywho Cargo workspace"
            echo "  -h, --help          Show this help"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

CARGO_PROFILE_FLAG=""
if [ "$BUILD_TYPE" = "release" ]; then
    CARGO_PROFILE_FLAG="--release"
fi

echo "========================================"
echo "Building NobodyWho Swift SDK"
echo "Build type:    $BUILD_TYPE"
echo "Workspace:     $WORKSPACE_DIR"
echo "========================================"

# Validate workspace
if [ ! -f "$WORKSPACE_DIR/Cargo.toml" ]; then
    echo "Error: Cargo workspace not found at $WORKSPACE_DIR"
    echo "  Set --workspace or NOBODYWHO_WORKSPACE to the nobodywho workspace directory."
    exit 1
fi

# Check for required tools
if ! command -v rustup &> /dev/null; then
    echo "Error: rustup not found. Please install Rust: https://rustup.rs"
    exit 1
fi
if ! command -v xcodebuild &> /dev/null; then
    echo "Error: xcodebuild not found. Please install Xcode."
    exit 1
fi

# Ensure iOS, macOS, visionOS, and watchOS targets are installed
echo ""
echo "Checking Rust targets..."
rustup target add \
    aarch64-apple-ios \
    aarch64-apple-ios-sim \
    x86_64-apple-ios \
    aarch64-apple-darwin \
    x86_64-apple-darwin \
    aarch64-apple-visionos \
    aarch64-apple-visionos-sim \
    aarch64-apple-watchos \
    aarch64-apple-watchos-sim \
    x86_64-apple-watchos-sim \
    2>/dev/null || true

# Helper to generate a CMake toolchain file for cross-compilation
# The cmake Rust crate only knows about iOS/macOS, so we need to help it
# with visionOS/watchOS by providing a toolchain file.
generate_cmake_toolchain() {
    local system_name="$1"
    local sdk_path="$2"
    local arch="$3"
    local extra_flags="${4:-}"
    local toolchain_file="$TARGET_DIR/cmake-toolchain-${system_name}-${arch}.cmake"

    cat > "$toolchain_file" <<TCEOF
set(CMAKE_SYSTEM_NAME ${system_name})
set(CMAKE_OSX_SYSROOT "${sdk_path}")
set(CMAKE_OSX_ARCHITECTURES "${arch}")

# Tell CMake to search for libraries/headers/packages inside the SDK sysroot
set(CMAKE_FIND_ROOT_PATH "${sdk_path}")
set(CMAKE_FIND_ROOT_PATH_MODE_LIBRARY BOTH)
set(CMAKE_FIND_ROOT_PATH_MODE_INCLUDE BOTH)
set(CMAKE_FIND_ROOT_PATH_MODE_PACKAGE BOTH)
set(CMAKE_FIND_FRAMEWORK FIRST)

# Disable OpenSSL support for cpp-httplib. When cross-compiling, CMake may
# find the host system's OpenSSL (e.g. from Homebrew), which enables
# CPPHTTPLIB_OPENSSL_SUPPORT, which in turn enables macOS Keychain cert
# loading (SecTrustCopyAnchorCertificates) - a macOS-only API not available
# on visionOS/watchOS. SSL is not needed for local LLM inference.
set(LLAMA_OPENSSL OFF CACHE BOOL "" FORCE)
${extra_flags}
TCEOF
    echo "$toolchain_file"
}

# Helper to create a stub .tbd framework that satisfies the linker.
# Used for frameworks that don't exist in certain SDKs (e.g. Metal on watchOS)
# but are unconditionally linked by upstream build scripts.
create_stub_framework() {
    local parent_dir="$1"
    local fw_name="$2"
    local targets="$3"  # space-separated list of tapi targets
    local fw_dir="$parent_dir/${fw_name}.framework"
    mkdir -p "$fw_dir"
    local tapi_targets
    tapi_targets=$(echo "$targets" | sed 's/ /, /g')
    cat > "$fw_dir/${fw_name}.tbd" <<TBDEOF
--- !tapi-tbd
tbd-version: 4
targets: [ ${tapi_targets} ]
install-name: /System/Library/Frameworks/${fw_name}.framework/${fw_name}
current-version: 1.0
exports: []
...
TBDEOF
}

# Helper to set only the deployment target and SDK for the current platform
set_deployment_target() {
    local platform="$1"
    local sim="$2"  # "sim" if building for simulator, empty otherwise
    local arch="${3:-arm64}"  # architecture, defaults to arm64
    unset IPHONEOS_DEPLOYMENT_TARGET
    unset MACOSX_DEPLOYMENT_TARGET
    unset XROS_DEPLOYMENT_TARGET
    unset WATCHOS_DEPLOYMENT_TARGET
    unset CMAKE_TOOLCHAIN_FILE
    unset CFLAGS
    unset CXXFLAGS
    unset RUSTFLAGS
    case "$platform" in
        ios)
            export IPHONEOS_DEPLOYMENT_TARGET=13.0
            if [ "$sim" = "sim" ]; then
                export SDKROOT=$(xcrun --sdk iphonesimulator --show-sdk-path)
            else
                export SDKROOT=$(xcrun --sdk iphoneos --show-sdk-path)
            fi
            ;;
        macos)
            export MACOSX_DEPLOYMENT_TARGET=11.0
            export SDKROOT=$(xcrun --sdk macosx --show-sdk-path)
            ;;
        visionos)
            export XROS_DEPLOYMENT_TARGET=1.0
            if [ "$sim" = "sim" ]; then
                local sdk_path=$(xcrun --sdk xrsimulator --show-sdk-path)
                export SDKROOT="$sdk_path"
                export CMAKE_TOOLCHAIN_FILE=$(generate_cmake_toolchain "visionOS" "$sdk_path" "$arch")
            else
                local sdk_path=$(xcrun --sdk xros --show-sdk-path)
                export SDKROOT="$sdk_path"
                export CMAKE_TOOLCHAIN_FILE=$(generate_cmake_toolchain "visionOS" "$sdk_path" "$arch")
            fi
            ;;
        watchos)
            export WATCHOS_DEPLOYMENT_TARGET=6.0
            # watchOS SDK headers hide BSD types and some sysconf constants
            # behind __DARWIN_C_FULL when _XOPEN_SOURCE=600 is defined (by llama.cpp).
            # Generate a compat header that restores them.
            # The __ASSEMBLER__ guard prevents errors when applied to .s files.
            local compat_header="$TARGET_DIR/watchos_bsd_compat.h"
            cat > "$compat_header" <<'COMPAT_EOF'
#ifndef _WATCHOS_BSD_COMPAT_H
#define _WATCHOS_BSD_COMPAT_H
#ifndef __ASSEMBLER__
typedef unsigned int u_int;
typedef unsigned char u_char;
typedef unsigned short u_short;
#ifndef _SC_PHYS_PAGES
#define _SC_PHYS_PAGES 200
#endif
#endif /* __ASSEMBLER__ */
#endif
COMPAT_EOF
            export CFLAGS="-include ${compat_header} ${CFLAGS:-}"
            export CXXFLAGS="-include ${compat_header} ${CXXFLAGS:-}"
            # Disable Metal (not available on watchOS) and force-include compat header
            local watchos_extra_flags="# Disable Metal (not available on watchOS)
set(GGML_METAL OFF CACHE BOOL \"\" FORCE)
# Force-include BSD compat header for watchOS
add_compile_options(-include ${compat_header})"
            # llama-cpp-sys-2 build.rs unconditionally links Metal/MetalKit on
            # Apple targets.  These frameworks don't exist in the watchOS SDK, so
            # we create stub .tbd files and point the linker at them via -F.
            local stub_fw_dir="$TARGET_DIR/watchos-stub-frameworks"
            create_stub_framework "$stub_fw_dir" "Metal" "arm64-watchos arm64-watchos-simulator x86_64-watchos-simulator"
            create_stub_framework "$stub_fw_dir" "MetalKit" "arm64-watchos arm64-watchos-simulator x86_64-watchos-simulator"
            export RUSTFLAGS="${RUSTFLAGS:-} -Clink-arg=-F${stub_fw_dir}"
            if [ "$sim" = "sim" ]; then
                local sdk_path=$(xcrun --sdk watchsimulator --show-sdk-path)
                export SDKROOT="$sdk_path"
                export CMAKE_TOOLCHAIN_FILE=$(generate_cmake_toolchain "watchOS" "$sdk_path" "$arch" "$watchos_extra_flags")
            else
                local sdk_path=$(xcrun --sdk watchos --show-sdk-path)
                export SDKROOT="$sdk_path"
                export CMAKE_TOOLCHAIN_FILE=$(generate_cmake_toolchain "watchOS" "$sdk_path" "$arch" "$watchos_extra_flags")
            fi
            ;;
    esac
}

# Tier 3 targets (visionOS, watchOS) need -Zbuild-std since there are no pre-built std libraries
BUILD_STD_FLAG="-Zbuild-std"

# Check for nightly toolchain (required for -Zbuild-std)
if ! rustup run nightly rustc --version &> /dev/null; then
    echo "Error: Rust nightly toolchain is required for visionOS/watchOS targets (-Zbuild-std)."
    echo "Install it with: rustup toolchain install nightly"
    exit 1
fi

# Use nightly for tier 3 targets
CARGO_NIGHTLY="cargo +nightly"

CARGO_MANIFEST="$WORKSPACE_DIR/Cargo.toml"

if [ "$SKIP_BUILD" = false ]; then
    echo ""
    echo "Building nobodywho-uniffi for all Apple targets..."

    echo "  [1/10] iOS device (aarch64-apple-ios)..."
    set_deployment_target ios
    cargo build -p nobodywho-uniffi --target aarch64-apple-ios $CARGO_PROFILE_FLAG --manifest-path "$CARGO_MANIFEST"

    echo "  [2/10] iOS simulator arm64 (aarch64-apple-ios-sim)..."
    set_deployment_target ios sim
    cargo build -p nobodywho-uniffi --target aarch64-apple-ios-sim $CARGO_PROFILE_FLAG --manifest-path "$CARGO_MANIFEST"

    echo "  [3/10] iOS simulator x86_64 (x86_64-apple-ios)..."
    set_deployment_target ios sim
    cargo build -p nobodywho-uniffi --target x86_64-apple-ios $CARGO_PROFILE_FLAG --manifest-path "$CARGO_MANIFEST"

    echo "  [4/10] macOS arm64 (aarch64-apple-darwin)..."
    set_deployment_target macos
    cargo build -p nobodywho-uniffi --target aarch64-apple-darwin $CARGO_PROFILE_FLAG --manifest-path "$CARGO_MANIFEST"

    echo "  [5/10] macOS x86_64 (x86_64-apple-darwin)..."
    set_deployment_target macos
    cargo build -p nobodywho-uniffi --target x86_64-apple-darwin $CARGO_PROFILE_FLAG --manifest-path "$CARGO_MANIFEST"

    # visionOS device (arm64) - tier 3, needs nightly + build-std
    echo "  [6/10] visionOS device (aarch64-apple-visionos)..."
    set_deployment_target visionos
    $CARGO_NIGHTLY build -p nobodywho-uniffi --target aarch64-apple-visionos $BUILD_STD_FLAG $CARGO_PROFILE_FLAG --manifest-path "$CARGO_MANIFEST"

    # visionOS simulator (arm64) - tier 3, needs nightly + build-std
    echo "  [7/10] visionOS simulator (aarch64-apple-visionos-sim)..."
    set_deployment_target visionos sim
    $CARGO_NIGHTLY build -p nobodywho-uniffi --target aarch64-apple-visionos-sim $BUILD_STD_FLAG $CARGO_PROFILE_FLAG --manifest-path "$CARGO_MANIFEST"

    # watchOS device (arm64) - tier 3, needs nightly + build-std
    rm -rf "$TARGET_DIR"/aarch64-apple-watchos/"$BUILD_TYPE"/build/llama-cpp-sys-2-* 2>/dev/null || true
    echo "  [8/10] watchOS device (aarch64-apple-watchos)..."
    set_deployment_target watchos "" arm64
    $CARGO_NIGHTLY build -p nobodywho-uniffi --target aarch64-apple-watchos $BUILD_STD_FLAG $CARGO_PROFILE_FLAG --manifest-path "$CARGO_MANIFEST"

    # watchOS simulator (arm64) - tier 3, needs nightly + build-std
    rm -rf "$TARGET_DIR"/aarch64-apple-watchos-sim/"$BUILD_TYPE"/build/llama-cpp-sys-2-* 2>/dev/null || true
    echo "  [9/10] watchOS simulator arm64 (aarch64-apple-watchos-sim)..."
    set_deployment_target watchos sim arm64
    $CARGO_NIGHTLY build -p nobodywho-uniffi --target aarch64-apple-watchos-sim $BUILD_STD_FLAG $CARGO_PROFILE_FLAG --manifest-path "$CARGO_MANIFEST"

    # watchOS simulator (x86_64) - tier 3, needs nightly + build-std
    rm -rf "$TARGET_DIR"/x86_64-apple-watchos-sim/"$BUILD_TYPE"/build/llama-cpp-sys-2-* 2>/dev/null || true
    echo "  [10/10] watchOS simulator x86_64 (x86_64-apple-watchos-sim)..."
    set_deployment_target watchos sim x86_64
    $CARGO_NIGHTLY build -p nobodywho-uniffi --target x86_64-apple-watchos-sim $BUILD_STD_FLAG $CARGO_PROFILE_FLAG --manifest-path "$CARGO_MANIFEST"
else
    echo ""
    echo "Skipping cargo build (--skip-build flag)"
fi

echo ""
echo "Generating Swift bindings..."

mkdir -p "$SWIFT_DIR/Sources/NobodyWho/Generated"

# Ensure only macOS deployment target is set for bindgen
set_deployment_target macos

cd "$WORKSPACE_DIR"
cargo run -p nobodywho-uniffi --bin uniffi-bindgen $CARGO_PROFILE_FLAG -- generate \
    --library "$TARGET_DIR/aarch64-apple-darwin/$BUILD_TYPE/${LIB_NAME}.dylib" \
    --language swift \
    --out-dir "$SWIFT_DIR/Sources/NobodyWho/Generated"
cd "$SWIFT_DIR"

echo "  Swift bindings written to Sources/NobodyWho/Generated/"

echo ""
echo "Creating universal static libraries..."

# Create universal simulator library (iOS)
mkdir -p "$TARGET_DIR/universal-ios-sim/$BUILD_TYPE"
lipo -create \
    "$TARGET_DIR/aarch64-apple-ios-sim/$BUILD_TYPE/${LIB_NAME}.a" \
    "$TARGET_DIR/x86_64-apple-ios/$BUILD_TYPE/${LIB_NAME}.a" \
    -output "$TARGET_DIR/universal-ios-sim/$BUILD_TYPE/${LIB_NAME}.a"

# Create universal macOS library
mkdir -p "$TARGET_DIR/universal-macos/$BUILD_TYPE"
lipo -create \
    "$TARGET_DIR/aarch64-apple-darwin/$BUILD_TYPE/${LIB_NAME}.a" \
    "$TARGET_DIR/x86_64-apple-darwin/$BUILD_TYPE/${LIB_NAME}.a" \
    -output "$TARGET_DIR/universal-macos/$BUILD_TYPE/${LIB_NAME}.a"

# Create universal watchOS simulator library
mkdir -p "$TARGET_DIR/universal-watchos-sim/$BUILD_TYPE"
lipo -create \
    "$TARGET_DIR/aarch64-apple-watchos-sim/$BUILD_TYPE/${LIB_NAME}.a" \
    "$TARGET_DIR/x86_64-apple-watchos-sim/$BUILD_TYPE/${LIB_NAME}.a" \
    -output "$TARGET_DIR/universal-watchos-sim/$BUILD_TYPE/${LIB_NAME}.a"

# Prepare a shared headers directory for all -library entries
HEADERS_DIR="$TARGET_DIR/xcframework-headers"
rm -rf "$HEADERS_DIR"
mkdir -p "$HEADERS_DIR"
[ -f "$SWIFT_DIR/Sources/NobodyWho/Generated/nobodywhoFFI.h" ] && \
    cp "$SWIFT_DIR/Sources/NobodyWho/Generated/nobodywhoFFI.h" "$HEADERS_DIR/"
[ -f "$SWIFT_DIR/Sources/NobodyWho/Generated/nobodywhoFFI.modulemap" ] && \
    cp "$SWIFT_DIR/Sources/NobodyWho/Generated/nobodywhoFFI.modulemap" "$HEADERS_DIR/module.modulemap"

echo ""
echo "Creating XCFramework..."
rm -rf "$XCFRAMEWORK_OUTPUT"

xcodebuild -create-xcframework \
    -library "$TARGET_DIR/aarch64-apple-ios/$BUILD_TYPE/${LIB_NAME}.a" \
    -headers "$HEADERS_DIR" \
    -library "$TARGET_DIR/universal-ios-sim/$BUILD_TYPE/${LIB_NAME}.a" \
    -headers "$HEADERS_DIR" \
    -library "$TARGET_DIR/universal-macos/$BUILD_TYPE/${LIB_NAME}.a" \
    -headers "$HEADERS_DIR" \
    -library "$TARGET_DIR/aarch64-apple-visionos/$BUILD_TYPE/${LIB_NAME}.a" \
    -headers "$HEADERS_DIR" \
    -library "$TARGET_DIR/aarch64-apple-visionos-sim/$BUILD_TYPE/${LIB_NAME}.a" \
    -headers "$HEADERS_DIR" \
    -library "$TARGET_DIR/aarch64-apple-watchos/$BUILD_TYPE/${LIB_NAME}.a" \
    -headers "$HEADERS_DIR" \
    -library "$TARGET_DIR/universal-watchos-sim/$BUILD_TYPE/${LIB_NAME}.a" \
    -headers "$HEADERS_DIR" \
    -output "$XCFRAMEWORK_OUTPUT"

echo ""
echo "========================================"
echo "Build complete!"
echo "XCFramework: $XCFRAMEWORK_OUTPUT"
echo "========================================"
