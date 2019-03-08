#!/bin/sh

# Source Helper Functions
source "$(dirname "$0")/helpers.sh"

heading "Bootstrapping Carthage"
has_command carthage || fail "Carthage must be installed"
do_carthage_bootstrap
