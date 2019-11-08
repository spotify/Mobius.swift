#!/bin/bash

# Source Helper Functions
source "$(dirname "$0")/helpers.sh"

has_command swiftlint || fail "swiftlint must be installed"
has_command swiftformat || fail "swiftformat must be installed"

run_formatters() {
  swiftformat --config .swiftformat --cache ignore "$@"
  swiftlint autocorrect "$@"
}
export -f run_formatters

if [ $# -eq 0 ]; then
  run_formatters \
    Mobius.playground \
    MobiusCore \
    MobiusExtras \
    MobiusNimble \
    MobiusTest
else
  run_formatters "$@"
fi
