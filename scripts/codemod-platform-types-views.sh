#!/usr/bin/env bash
#
# codemod-platform-types-views.sh
#
# Issue #30: Replace UIKit types with RCT platform-abstraction types
# in React/Views/ header files.
#
# Usage:
#   ./scripts/codemod-platform-types-views.sh /path/to/clean/rn-checkout
#
# The checkout should contain React/Views/ at its root (e.g. upstream-rn-0.84.1/).
# This script modifies .h files in-place. Run against a clean upstream copy,
# then generate a diff against vanilla upstream.

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <path-to-clean-rn-checkout>" >&2
  exit 1
fi

RN_ROOT="$1"
VIEWS_DIR="${RN_ROOT}/React/Views"

if [[ ! -d "$VIEWS_DIR" ]]; then
  echo "Error: ${VIEWS_DIR} does not exist." >&2
  exit 1
fi

MODIFIED=0
SKIPPED=0

# Process every .h file under React/Views/
while IFS= read -r -d '' file; do
  # Skip files that already use RCTUIKit.h or RCTPlatformView
  if grep -q 'RCTUIKit\.h\|RCTPlatformView' "$file" 2>/dev/null; then
    SKIPPED=$((SKIPPED + 1))
    continue
  fi

  # Check if file has anything to replace
  if ! grep -qE 'UIKit/UIKit\.h|UIKit/UIScrollView\.h|UIView|UIColor|UIScrollView|UIViewController|UIAccessibilityTraits' "$file" 2>/dev/null; then
    continue
  fi

  # --- Import replacement ---
  # Replace #import <UIKit/UIKit.h> with #import <React/RCTUIKit.h>
  sed -i '' 's|#import <UIKit/UIKit\.h>|#import <React/RCTUIKit.h>|g' "$file"
  # Replace #import <UIKit/UIScrollView.h> with #import <React/RCTUIKit.h>
  sed -i '' 's|#import <UIKit/UIScrollView\.h>|#import <React/RCTUIKit.h>|g' "$file"

  # --- Category declarations: @interface UIView (...) ---
  # e.g. @interface UIView (React) -> @interface RCTPlatformView (React)
  sed -i '' 's/@interface UIView (/@interface RCTPlatformView (/g' "$file"

  # --- Superclass: ": UIView" (with optional protocol conformance) ---
  # ": UIView<" (no space before angle bracket)
  sed -i '' 's/: UIView</: RCTUIView</g' "$file"
  # ": UIView " at end of @interface line (space or newline follows)
  sed -i '' 's/: UIView$/: RCTUIView/g' "$file"
  # ": UIView " followed by space (e.g. before newline in @interface RCTView : UIView\n)
  # Handle ": UIView" followed by end-of-line, space, or newline
  # Use word boundary approach: replace ": UIView" only when not followed by alnum
  sed -i '' -E 's/: UIView([^A-Za-z0-9_])/: RCTUIView\1/g' "$file"

  # --- ": UIViewController" superclass ---
  sed -i '' -E 's/: UIViewController([^A-Za-z0-9_])/: RCTPlatformViewController\1/g' "$file"
  sed -i '' 's/: UIViewController$/: RCTPlatformViewController/g' "$file"

  # --- @protocol UIScrollViewDelegate; forward declaration ---
  sed -i '' 's/@protocol UIScrollViewDelegate;/@protocol RCTUIScrollViewDelegate;/g' "$file"

  # --- UIScrollViewDelegate in protocol conformance and parameter types ---
  # Must come before UIScrollView * replacement to avoid partial matches
  sed -i '' -E 's/UIScrollViewDelegate/RCTUIScrollViewDelegate/g' "$file"

  # --- UIScrollView * (pointer type) ---
  sed -i '' 's/UIScrollView \*/RCTUIScrollView */g' "$file"

  # --- UIView * (pointer type in params, returns, properties, generics) ---
  sed -i '' 's/UIView \*/RCTPlatformView */g' "$file"

  # --- UIView< (protocol-qualified pointer type, e.g. (UIView<SomeProtocol> *)) ---
  # The superclass rule already converted ": UIView<" to ": RCTUIView<"
  # This catches remaining UIView< in parameter types / casts
  sed -i '' 's/(UIView</(RCTPlatformView</g' "$file"

  # --- UIColor * ---
  sed -i '' 's/UIColor \*/RCTUIColor */g' "$file"

  # --- UIViewController * (pointer type) ---
  sed -i '' 's/UIViewController \*/RCTPlatformViewController */g' "$file"

  # --- UIAccessibilityTraits ---
  sed -i '' 's/UIAccessibilityTraits/RCTUIAccessibilityTraits/g' "$file"

  MODIFIED=$((MODIFIED + 1))
done < <(find "$VIEWS_DIR" -name '*.h' -print0)

echo "Done. Modified: ${MODIFIED} files, Skipped: ${SKIPPED} files (already converted)."
