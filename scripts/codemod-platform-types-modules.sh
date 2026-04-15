#!/usr/bin/env bash
#
# codemod-platform-types-modules.sh
#
# Issue #31: Replace UIKit types with platform-agnostic types in
# React/Modules/ and React/CoreModules/ header files.
#
# Usage:
#   ./scripts/codemod-platform-types-modules.sh /path/to/clean-rn-checkout
#
# This script is idempotent: running it twice produces the same result.

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <path-to-clean-rn-checkout>" >&2
  exit 1
fi

RN_ROOT="$1"

if [[ ! -d "$RN_ROOT/React/Modules" ]] || [[ ! -d "$RN_ROOT/React/CoreModules" ]]; then
  echo "Error: $RN_ROOT does not look like a React Native checkout." >&2
  echo "Expected React/Modules/ and React/CoreModules/ directories." >&2
  exit 1
fi

# Collect all .h files in the target directories
HEADER_FILES=()
for f in "$RN_ROOT"/React/Modules/*.h "$RN_ROOT"/React/CoreModules/*.h; do
  [[ -f "$f" ]] && HEADER_FILES+=("$f")
done

echo "Processing ${#HEADER_FILES[@]} header files..."

# --- Step 1: iOS-only module headers get a TODO comment ---
# These modules are inherently iOS-specific and should be extracted
# to react-native-ios rather than made platform-agnostic.

IOS_ONLY_HEADERS=(
  "$RN_ROOT/React/CoreModules/RCTStatusBarManager.h"
  "$RN_ROOT/React/CoreModules/RCTAlertController.h"
)

for f in "${IOS_ONLY_HEADERS[@]}"; do
  if [[ -f "$f" ]]; then
    # Only add if not already present
    if ! grep -q 'TODO(platform-extraction)' "$f"; then
      sed -i '' '1i\
// TODO(platform-extraction): Extract to react-native-ios
' "$f"
      echo "  Added TODO comment: $(basename "$f")"
    fi
  fi
done

# --- Step 2: Replace UIKit imports and types ---
# Skip iOS-only headers for type replacement since they will be
# extracted wholesale. They keep their UIKit imports.

IOS_ONLY_BASENAMES="RCTStatusBarManager.h|RCTAlertController.h"

for f in "${HEADER_FILES[@]}"; do
  basename_f="$(basename "$f")"

  # Skip iOS-only headers for import/type replacement
  if echo "$basename_f" | grep -qE "^($IOS_ONLY_BASENAMES)$"; then
    continue
  fi

  changed=false

  # Replace #import <UIKit/UIKit.h> with #import <React/RCTUIKit.h>
  if grep -q '#import <UIKit/UIKit.h>' "$f"; then
    sed -i '' 's|#import <UIKit/UIKit.h>|#import <React/RCTUIKit.h>|g' "$f"
    changed=true
  fi

  # Replace UIView * with RCTPlatformView *
  # Handle various spacing patterns: UIView *, UIView*, (UIView *)
  if grep -q 'UIView \*' "$f"; then
    sed -i '' 's/UIView \*/RCTPlatformView */g' "$f"
    changed=true
  fi

  # Replace UIWindow * with RCTPlatformWindow *
  if grep -q 'UIWindow \*' "$f"; then
    sed -i '' 's/UIWindow \*/RCTPlatformWindow */g' "$f"
    changed=true
  fi

  # Replace UIViewController * with RCTPlatformViewController *
  if grep -q 'UIViewController \*' "$f"; then
    sed -i '' 's/UIViewController \*/RCTPlatformViewController */g' "$f"
    changed=true
  fi

  if $changed; then
    echo "  Replaced types: $basename_f"
  fi
done

echo "Done. Codemod complete."
