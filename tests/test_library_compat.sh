#!/usr/bin/env bash
#
# test_library_compat.sh
# Checks that top ecosystem libraries' native iOS code is compatible with the
# RCTConvert header split (core + UIKit category with compat re-export).
#
# Usage: ./test_library_compat.sh [path-to-node_modules]
#
# Exit codes:
#   0 - all libraries pass
#   1 - one or more libraries fail

set -euo pipefail

NODE_MODULES="${1:-/Users/sethagent/Developer/MacOSTestApp/node_modules}"

# UIKit-category methods that are ONLY declared in RCTConvert+UIKit.h
# If a library calls these and the .h is a stub, it will get warnings/errors.
UIKIT_METHODS=(
  "UIColor:"
  "UIColorWithRed:"
  "CGColor:"
  "UIEdgeInsets:"
  "UIImage:"
  "CGImage:"
  "UIColorArray:"
  "CGColorArray:"
  "UITextAutocapitalizationType:"
  "UITextFieldViewMode:"
  "UIKeyboardType:"
  "UIDataDetectorTypes:"
  "UIKeyboardAppearance:"
  "UIReturnKeyType:"
  "UIUserInterfaceStyle:"
  "UIInterfaceOrientationMask:"
  "UIModalPresentationStyle:"
  "UIViewContentMode:"
)

LIBRARIES=(
  "react-native-screens"
  "react-native-gesture-handler"
  "react-native-reanimated"
  "react-native-svg"
  "lottie-react-native"
  "react-native-safe-area-context"
  "react-native-device-info"
  "react-native-linear-gradient"
)

# Build a single grep pattern for UIKit methods
UIKIT_PATTERN=""
for method in "${UIKIT_METHODS[@]}"; do
  if [ -n "$UIKIT_PATTERN" ]; then
    UIKIT_PATTERN="${UIKIT_PATTERN}|"
  fi
  UIKIT_PATTERN="${UIKIT_PATTERN}RCTConvert ${method}"
done

PASS_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0

echo "============================================"
echo "Library Compat Test: RCTConvert Header Split"
echo "============================================"
echo ""

# Check if RCTConvert+UIKit.h is a stub or has real declarations
UIKIT_HEADER="${NODE_MODULES}/react-native/React/Base/RCTConvert+UIKit.h"
if [ -f "$UIKIT_HEADER" ]; then
  DECL_COUNT=$(grep -cE '@interface|^\+\s*\(' "$UIKIT_HEADER" 2>/dev/null || true)
  DECL_COUNT="${DECL_COUNT:-0}"
  if [ "$DECL_COUNT" -eq 0 ]; then
    echo "WARNING: RCTConvert+UIKit.h appears to be a stub (no declarations found)."
    echo "         Libraries using UIKit category methods will fail to compile."
    echo ""
    STUB_HEADER=true
  else
    echo "INFO: RCTConvert+UIKit.h has declarations ($DECL_COUNT found)."
    echo ""
    STUB_HEADER=false
  fi
else
  echo "WARNING: RCTConvert+UIKit.h not found at $UIKIT_HEADER"
  echo ""
  STUB_HEADER=true
fi

# Check compat re-export in RCTConvert.h
MAIN_HEADER="${NODE_MODULES}/react-native/React/Base/RCTConvert.h"
if [ -f "$MAIN_HEADER" ]; then
  if grep -q 'RCTConvert+UIKit.h' "$MAIN_HEADER"; then
    echo "INFO: RCTConvert.h includes compat re-export of RCTConvert+UIKit.h"
  else
    echo "WARNING: RCTConvert.h does NOT include compat re-export!"
  fi
fi
echo ""

for lib in "${LIBRARIES[@]}"; do
  LIB_DIR="${NODE_MODULES}/${lib}"

  if [ ! -d "$LIB_DIR" ]; then
    echo "[$lib] SKIP - not installed"
    SKIP_COUNT=$((SKIP_COUNT + 1))
    continue
  fi

  # Find all .m/.mm/.h files
  NATIVE_FILES=$(find "$LIB_DIR" \( -name "*.m" -o -name "*.mm" -o -name "*.h" \) 2>/dev/null)

  if [ -z "$NATIVE_FILES" ]; then
    echo "[$lib] SKIP - no native iOS files"
    SKIP_COUNT=$((SKIP_COUNT + 1))
    continue
  fi

  # Check for any RCTConvert reference
  HAS_RCTCONVERT=$(echo "$NATIVE_FILES" | xargs grep -l "RCTConvert" 2>/dev/null || true)

  if [ -z "$HAS_RCTCONVERT" ]; then
    echo "[$lib] PASS - no RCTConvert references"
    PASS_COUNT=$((PASS_COUNT + 1))
    continue
  fi

  # Check for UIKit category method usage
  UIKIT_USAGE=$(echo "$NATIVE_FILES" | xargs grep -n "\\[RCTConvert " 2>/dev/null | grep -E "$UIKIT_PATTERN" || true)

  if [ -z "$UIKIT_USAGE" ]; then
    echo "[$lib] PASS - uses RCTConvert but no UIKit category methods"
    PASS_COUNT=$((PASS_COUNT + 1))
  else
    if [ "$STUB_HEADER" = true ]; then
      echo "[$lib] FAIL - uses UIKit category methods (stub header = no declarations):"
      echo "$UIKIT_USAGE" | sed 's/^/    /'
      FAIL_COUNT=$((FAIL_COUNT + 1))
    else
      echo "[$lib] PASS - uses UIKit category methods (header has declarations):"
      echo "$UIKIT_USAGE" | sed 's/^/    /'
      PASS_COUNT=$((PASS_COUNT + 1))
    fi
  fi
  echo ""
done

echo "============================================"
echo "Results: $PASS_COUNT PASS, $FAIL_COUNT FAIL, $SKIP_COUNT SKIP"
echo "============================================"

if [ "$FAIL_COUNT" -gt 0 ]; then
  echo ""
  echo "FAILURE: $FAIL_COUNT libraries use UIKit category methods that are not"
  echo "declared in the stub RCTConvert+UIKit.h. The header must include proper"
  echo "@interface declarations for these methods."
  exit 1
fi

exit 0
