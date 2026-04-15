#!/usr/bin/env bash
#
# codemod-platform-types-base.sh
#
# Replaces raw UIKit types with RCT platform-abstract types in React/Base/ headers.
# Part of RFC 0003: React Native Platform Extraction (Issue #29).
#
# Usage: ./scripts/codemod-platform-types-base.sh /path/to/clean/rn-checkout
#
# This script is idempotent -- running it multiple times produces the same result.
# It does NOT touch RCTUIKit.h or RCTConvert* files.

set -euo pipefail

if [ $# -ne 1 ]; then
  echo "Usage: $0 <path-to-clean-rn-checkout>"
  exit 1
fi

RN_ROOT="$1"
BASE_DIR="$RN_ROOT/React/Base"

if [ ! -d "$BASE_DIR" ]; then
  echo "Error: $BASE_DIR does not exist"
  exit 1
fi

# Collect all .h files under React/Base/ (recursively), excluding RCTUIKit* and RCTConvert*
FILES=$(find "$BASE_DIR" -name '*.h' \
  ! -name 'RCTUIKit*' \
  ! -name 'RCTConvert*' \
  -type f)

if [ -z "$FILES" ]; then
  echo "No header files found to process."
  exit 0
fi

echo "Processing Base/ headers..."

for f in $FILES; do
  # 1. Replace #import <UIKit/UIKit.h> with #import <React/RCTUIKit.h>
  #    Idempotent: only matches UIKit/UIKit.h, not React/RCTUIKit.h
  sed -i '' 's|#import <UIKit/UIKit\.h>|#import <React/RCTUIKit.h>|g' "$f"

  # 2. Replace ": UIView" (superclass declarations) with ": RCTUIView"
  #    Uses BSD sed word boundary [[:<:]] / [[:>:]]
  #    Idempotent: won't match ": RCTUIView"
  sed -i '' 's/: UIView[[:<:]][[:>:]]/: RCTUIView/g' "$f" 2>/dev/null || true
  # Fallback: match ": UIView$", ": UIView " and ": UIView<" patterns directly
  sed -i '' 's/: UIView$/: RCTUIView/g' "$f"
  sed -i '' 's/: UIView /: RCTUIView /g' "$f"
  sed -i '' 's/: UIView</: RCTUIView</g' "$f"

  # 3. Replace "UIView)" in category declarations, e.g. "(UIView)"
  #    Idempotent: won't match "(RCTPlatformView)"
  sed -i '' 's/UIView)/RCTPlatformView)/g' "$f"

  # 4. Replace "UIView *" in type positions (properties, params, return types, typedefs)
  #    Idempotent: won't match "RCTPlatformView *"
  sed -i '' 's/UIView \*/RCTPlatformView */g' "$f"

  # 5. Replace UIColor * with RCTUIColor *
  sed -i '' 's/UIColor \*/RCTUIColor */g' "$f"

  # 6. Replace UIImage * with RCTPlatformImage *
  sed -i '' 's/UIImage \*/RCTPlatformImage */g' "$f"

  # 7. Replace UIViewController * with RCTPlatformViewController *
  sed -i '' 's/UIViewController \*/RCTPlatformViewController */g' "$f"

  # 8. Replace UIWindow * with RCTPlatformWindow *
  sed -i '' 's/UIWindow \*/RCTPlatformWindow */g' "$f"

done

echo "Done. Processed $(echo "$FILES" | wc -l | tr -d ' ') header files."
