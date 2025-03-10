#!/bin/bash

# Source Helper Functions
source "$(dirname "$0")/helpers.sh"

# SPM build and test
swift test --enable-code-coverage --sanitize=thread || fail "SPM Test Failed"

# Process codecov
process_coverage -D ".build/debug/codecov" -F "macspm"
