# Development Rules

## Never patch node_modules

All changes targeting upstream React Native MUST be made against a clean
upstream checkout — never in node_modules. node_modules contains macOS
patches from postinstall that make diffs unextractable.

**Why:** We learned this the hard way. Wave 2 type codemods were applied
in node_modules on top of 248 macOS patches. The result couldn't be
diffed against upstream, making the work un-PR-able. Days of validated
work had to be redone.

**How to work correctly:**
1. Keep a clean upstream RN checkout (e.g., `/tmp/rn-diff-work/react-native-0.84.1/`)
2. Make extraction changes there — or write codemod scripts that run against it
3. Generate diffs against vanilla upstream
4. Validate by applying the diff to node_modules, then building
5. Never edit node_modules directly as the source of truth

## Codemod over manual edits

Mechanical changes (type replacements, import swaps) must be implemented
as reproducible scripts, not manual find-and-replace. Scripts can be
re-run when upstream updates, reviewed in PRs, and verified independently.

## Test-first

Every extraction step needs a test that fails before the change and passes
after. Write the test first. This is especially important for AI-driven
work where regressions are easy to miss.

## Platform extraction context

This repo implements RFC 0003: React Native Platform Extraction. The goal
is to make RN core platform-agnostic and extract iOS/Android into peer
platform packages. See `rfcs/0003-platform-extraction.md`.

Key principle: we are NOT patching RN to add macOS support. We are
extracting iOS OUT of RN core so all platforms are equal peers.
