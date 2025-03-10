#!/bin/bash

# Source Helper Functions
source "$(dirname "$0")/helpers.sh"

# SPM build and test
swift test --enable-code-coverage --sanitize=thread || fail "SPM Test Failed"

# h4x to trick codecov
for bundle in .build/debug/*.xctest ; do
  parent="$(dirname "$bundle")"
  ln -sf "$PWD/$bundle" "${parent}/codecov"
done

process_coverage -D ".build/x86_64-apple-macosx/debug" -F "macspm"
