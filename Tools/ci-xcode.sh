#!/bin/bash

# Source Helper Functions
source "$(dirname "$0")/helpers.sh"

# Copy umbrella scheme to the xcschemes directory. 
# We don't want to check it in otherwise Carthage also builds it needlessly.
cp "$(dirname "$0")/ZZZ_MOBIUS_ALL.xcscheme" "$(dirname "$0")/../Mobius.xcodeproj/xcshareddata/xcschemes"

# Only install tools when running in CI
if [[ "$IS_CI" == "1" ]]; then
  heading "Installing Tools"
  brew install carthage xcbeautify
  export IS_CI=1
fi

has_command carthage || fail "Carthage must be installed"
has_command xcbeautify || fail "xcbeautify must be installed"

#
# Bootstrap with Carthage
#
heading "Bootstrapping Carthage"
do_carthage_bootstrap

#
# Build frameworks and libraries in release mode
#
heading "Building for Device (Release)"
xcb build \
  -scheme ZZZ_MOBIUS_ALL \
  -destination generic/platform=iOS \
  -configuration Release \
  -derivedDataPath build/DD/Build || \
  fail "Build for Device Failed"

heading "Building for Simulator (Release)"
xcb build \
  -scheme ZZZ_MOBIUS_ALL \
  -destination "generic/platform=iOS Simulator" \
  -configuration Release \
  -derivedDataPath build/DD/Build || \
  fail "Build for Simulator Failed"

#
# Run Tests
#
heading "Running Tests"

if ! sh -c 'xcrun simctl list devices | grep -q mobius-tester' ; then
  echo "Creating mobius-tester device"
  LATEST_RUNTIME=`xcrun simctl list runtimes | grep iOS | awk '{print $NF}' | tail -n 1`
  xcrun simctl create "mobius-tester" \
    "com.apple.CoreSimulator.SimDeviceType.iPhone-7" \
    "$LATEST_RUNTIME" || fail "Failed to create simulator for testing"
fi

rm -rf build/TestBundle
TEST_DERIVED_DATA_DIR="build/DD/Test"

xcb test \
  -scheme ZZZ_MOBIUS_ALL \
  -configuration Debug \
  -enableCodeCoverage YES \
  -resultBundlePath build/TestBundle \
  -derivedDataPath "$TEST_DERIVED_DATA_DIR" \
  -destination "platform=iOS Simulator,name=mobius-tester" || \
  fail "Test Run Failed"

process_coverage -D "$TEST_DERIVED_DATA_DIR" -F ios
