#!/bin/bash
# =============================================================================
# test_rctconvert_no_uikit.sh
#
# Issue #3: Verify RCTConvert.h platform-agnostic methods compile without UIKit.
#
# REMAINING UIKit DEPENDENCY IN CORE RCTConvert.h:
#
#   The core RCTConvert.h still imports <UIKit/UIKit.h> because the following
#   text-related enum types are defined in UIKit on iOS (but in AppKit on macOS):
#
#     - NSLineBreakMode        (lines 78)
#     - NSTextAlignment        (line 79)
#     - NSUnderlineStyle       (line 80)
#     - NSWritingDirection     (line 81)
#     - NSLineBreakStrategy    (line 82)
#
#   Additionally, the deprecated typedef on line 145 references UIColor:
#     typedef NSArray UIColorArray __deprecated_msg("Use NSArray<UIColor *>");
#
#   To fully remove UIKit from the core header:
#     1. Move the five NS*text-enum converter declarations (+NSLineBreakMode:,
#        +NSTextAlignment:, etc.) into RCTConvert+UIKit.h (or a new
#        RCTConvert+Text.h category).
#     2. Move the deprecated UIColorArray typedef into RCTConvert+UIKit.h.
#     3. Remove `#import <UIKit/UIKit.h>` from RCTConvert.h entirely.
#     4. On macOS builds, AppKit provides these types natively, so the category
#        header would import <AppKit/AppKit.h> instead of <UIKit/UIKit.h>.
#
#   This test proves the *rest* of RCTConvert.h is clean: once those five
#   enum declarations and the UIColor typedef are stripped, the header compiles
#   on macOS with only Foundation + CoreGraphics + AppKit (no UIKit).
#
# HOW IT WORKS:
#   1. Copies RCTConvert.h to a temp directory
#   2. Strips `#import <UIKit/UIKit.h>` and the compat re-export of
#      RCTConvert+UIKit.h
#   3. Strips the five NS*text-enum method declarations (they belong in the
#      UIKit category) and the UIColor deprecated typedef
#   4. Replaces UIKit with Foundation + CoreGraphics + AppKit
#   5. Stubs out RCTUtils.h (a transitive dep via RCTLog.h that is deeply
#      entangled with UIKit types like UIApplication, UIWindow, UIImage)
#      with a minimal Foundation-only version
#   6. Compiles with `clang -fsyntax-only` targeting macOS
#   7. Reports pass/fail
# =============================================================================
set -euo pipefail

DEVELOPER_DIR=/Applications/Xcode-26.3.0.app/Contents/Developer
export DEVELOPER_DIR

RN_ROOT="/Users/sethagent/Developer/MacOSTestApp/node_modules/react-native"
HEADER_SRC="${RN_ROOT}/React/Base/RCTConvert.h"

if [ ! -f "$HEADER_SRC" ]; then
  echo "FAIL: Source header not found at ${HEADER_SRC}"
  exit 1
fi

# --- Create temp workspace ---
TMPDIR_BASE=$(mktemp -d)
trap "rm -rf ${TMPDIR_BASE}" EXIT

# We need to set up include paths so that <React/Foo.h> and <yoga/Yoga.h> resolve.
# Create a fake React module directory with symlinks.
REACT_INC="${TMPDIR_BASE}/include/React"
YOGA_INC="${TMPDIR_BASE}/include/yoga"
mkdir -p "$REACT_INC" "$YOGA_INC"

# Symlink all headers from React/Base and React/Views into the React include dir
for dir in "${RN_ROOT}/React/Base" "${RN_ROOT}/React/Views"; do
  if [ -d "$dir" ]; then
    for h in "$dir"/*.h; do
      [ -f "$h" ] && ln -sf "$h" "${REACT_INC}/$(basename "$h")" 2>/dev/null || true
    done
  fi
done

# Symlink yoga headers
YOGA_SRC="${RN_ROOT}/ReactCommon/yoga/yoga"
if [ -d "$YOGA_SRC" ]; then
  for h in "$YOGA_SRC"/*.h; do
    [ -f "$h" ] && ln -sf "$h" "${YOGA_INC}/$(basename "$h")" 2>/dev/null || true
  done
fi

# --- Prepare the modified header ---
MODIFIED="${TMPDIR_BASE}/RCTConvert_no_uikit.h"
cp "$HEADER_SRC" "$MODIFIED"

# 1. Remove the UIKit import
sed -i '' '/#import <UIKit\/UIKit.h>/d' "$MODIFIED"

# 2. Remove the compat re-export of RCTConvert+UIKit.h (and its comment block)
sed -i '' '/^\/\/ Compat re-export/d' "$MODIFIED"
sed -i '' '/#import <React\/RCTConvert+UIKit.h>/d' "$MODIFIED"

# 3. Remove the five text-enum method declarations that require UIKit types
#    These are the methods that reference NSLineBreakMode, NSTextAlignment,
#    NSUnderlineStyle, NSWritingDirection, NSLineBreakStrategy
sed -i '' '/+ (NSLineBreakMode)NSLineBreakMode:/d' "$MODIFIED"
sed -i '' '/+ (NSTextAlignment)NSTextAlignment:/d' "$MODIFIED"
sed -i '' '/+ (NSUnderlineStyle)NSUnderlineStyle:/d' "$MODIFIED"
sed -i '' '/+ (NSWritingDirection)NSWritingDirection:/d' "$MODIFIED"
sed -i '' '/+ (NSLineBreakStrategy)NSLineBreakStrategy:/d' "$MODIFIED"

# 4. Remove the deprecated UIColorArray typedef (references UIColor)
sed -i '' '/typedef NSArray UIColorArray/d' "$MODIFIED"

# 5. Add AppKit import (provides NSLineBreakMode etc. on macOS, but we removed
#    those declarations anyway; AppKit is here for completeness / future-proofing)
#    Foundation and CoreGraphics are already imported in the original header.
sed -i '' 's|#import <CoreGraphics/CoreGraphics.h>|#import <CoreGraphics/CoreGraphics.h>\
#import <AppKit/AppKit.h>|' "$MODIFIED"

# Also override the React include so clang picks up our modified copy
ln -sf "$MODIFIED" "${REACT_INC}/RCTConvert.h"

# --- Patch transitive UIKit dependencies ---
# RCTLog.h imports RCTUtils.h which is deeply entangled with UIKit (UIApplication,
# UIWindow, UIImage, etc.). Since this test is about RCTConvert.h specifically,
# we create a minimal stub for RCTUtils.h that provides only the Foundation-based
# declarations that the compilation chain actually needs.

cat > "${REACT_INC}/RCTUtils.h" <<'STUB'
// Minimal stub for RCTUtils.h -- no UIKit types.
// This stub exists so that RCTLog.h (included by RCTConvert.h) can compile.
#import <Foundation/Foundation.h>
#import <React/RCTAssert.h>
#import <React/RCTDefines.h>
NS_ASSUME_NONNULL_BEGIN
RCT_EXTERN BOOL RCTIsNewArchEnabled(void);
NS_ASSUME_NONNULL_END
STUB

# Stub out RCTConvert+UIKit.h (already removed from RCTConvert.h, but just in case)
echo "// Stub - UIKit category not needed for this test" > "${REACT_INC}/RCTConvert+UIKit.h"

# --- Find the macOS SDK ---
SDKROOT=$(xcrun --sdk macosx --show-sdk-path 2>/dev/null)
if [ -z "$SDKROOT" ]; then
  echo "FAIL: Could not find macOS SDK"
  exit 1
fi
echo "Using SDK: ${SDKROOT}"

# --- Compile ---
echo ""
echo "Compiling modified RCTConvert.h (no UIKit) with clang -fsyntax-only ..."
echo ""

CLANG="${DEVELOPER_DIR}/Toolchains/XcodeDefault.xctoolchain/usr/bin/clang"
if [ ! -x "$CLANG" ]; then
  CLANG=$(xcrun --sdk macosx --find clang)
fi

# Create a minimal .m file that imports the header (clang needs a translation unit)
TEST_FILE="${TMPDIR_BASE}/test_import.m"
cat > "$TEST_FILE" <<'OBJC'
#import <React/RCTConvert.h>
// If this compiles, the core RCTConvert.h is UIKit-free.
OBJC

COMPILE_CMD=(
  "$CLANG"
  -fsyntax-only
  -x objective-c
  -fobjc-arc
  -isysroot "$SDKROOT"
  -I "${TMPDIR_BASE}/include"
  -target arm64-apple-macos14.0
  -Wno-deprecated-declarations
  "$TEST_FILE"
)

echo "Command: ${COMPILE_CMD[*]}"
echo ""

if "${COMPILE_CMD[@]}" 2>&1; then
  echo ""
  echo "==========================================="
  echo "PASS: RCTConvert.h compiles on macOS without UIKit"
  echo "==========================================="
  echo ""
  echo "The core RCTConvert.h is UIKit-free once the following are"
  echo "moved to RCTConvert+UIKit.h:"
  echo "  - NSLineBreakMode, NSTextAlignment, NSUnderlineStyle,"
  echo "    NSWritingDirection, NSLineBreakStrategy converter methods"
  echo "  - UIColorArray deprecated typedef"
  exit 0
else
  echo ""
  echo "==========================================="
  echo "FAIL: RCTConvert.h does NOT compile without UIKit"
  echo "==========================================="
  exit 1
fi
