# Development Rules — READ BEFORE DOING ANYTHING

## CRITICAL: All code changes go on the fork

The upstream RN fork is at `/Users/sethagent/Developer/react-native-upstream`
(repo: seth-agent/react-native-upstream, branch: platform-extraction).

**ALL changes to React Native code MUST be committed to the fork.**
Not node_modules. Not a temp directory. Not "just for testing."
The fork. Always. No exceptions.

This rule has been violated THREE TIMES in this project. Each time,
hours of work were lost because changes in node_modules disappear
on reinstall and can't be diffed against upstream.

**If you find yourself editing node_modules — STOP. You are doing
it wrong. Go to the fork.**

## CRITICAL: Keep the GitHub board updated

Milestone board: github.com/seth-agent/react-native-macos-official/milestones

Before starting work:
1. Check the board for the current milestone and open issues
2. Pick an issue or create one
3. Comment on it that you're starting

While working:
4. Close issues as you complete them with a summary comment
5. If you discover new work, create issues for it

This is how state persists across sessions. If you skip this, the
next session starts blind.

## CRITICAL: Short tasks, not long sessions

This project exceeds a single context window. Do NOT try to do
everything in one session. Instead:
- Pick ONE issue from the board
- Do it on the fork
- Commit, push, close the issue
- Stop or pick the next one

## Never patch node_modules

node_modules is for VALIDATION ONLY (build testing). Never treat
it as source of truth. Changes there are throwaway.

The fork at /Users/sethagent/Developer/react-native-upstream is
the source of truth for upstream RN changes.

## Work on forks, not patches

Don't generate .patch files. Fork the repo, make commits, push.
Patches and codemod scripts are indirection. On a fork you just
edit, commit, rebase.

## Test-first

Every change needs a test that fails before and passes after.
Write the test first.

## Platform extraction context

This repo implements RFC 0003: React Native Platform Extraction.
See `rfcs/0003-platform-extraction.md`.

**Key repos:**
- OOT macOS package: seth-agent/react-native-macos-official
- Upstream RN fork: seth-agent/react-native-upstream (branch: platform-extraction)
- Test app: /Users/sethagent/Developer/MacOSTestApp

**Current state (as of 2026-04-14):**
- Fork has 5 commits: RCTConvert split, type migration (150 files),
  RCTUIKit.h abstraction layer
- Shared ObjC layer compiles for macOS with zero UIView refs remaining
- Remaining work: OOT Fabric C++ event types, view implementation gaps
  (backgroundColor/userInteractionEnabled on NSView)
