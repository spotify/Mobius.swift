#!/bin/bash

# Source Helper Functions
source "$(dirname "$0")/helpers.sh"

# Copy umbrella scheme to the xcschemes directory. 
# We don't want to check it in otherwise Carthage also builds it needlessly.
cp "$(dirname "$0")/ZZZ_MOBIUS_ALL.xcscheme" "$(dirname "$0")/../Mobius.xcodeproj/xcshareddata/xcschemes"

# Only install tools when running on travis
if [[ "$IS_CI" == "1" ]]; then
  heading "Installing Tools"
  brew install carthage
  gem install xcpretty
  export IS_CI=1
fi

has_command carthage || fail "Carthage must be installed"
has_command xcpretty || fail "xcpretty must be installed"

#
# Bootstrap with Carthage
#
heading "Bootstrapping Carthage"
do_carthage_bootstrap

#
# Build frameworks and libraries in release mode
#
heading "Building for Device"
xcb build \
  -scheme ZZZ_MOBIUS_ALL \
  -destination generic/platform=iOS \
  -configuration Release \
  -derivedDataPath build/DD/Build || \
  fail "Build for Device Failed"

heading "Building for Simulator"
xcb build \
  -scheme ZZZ_MOBIUS_ALL \
  -sdk iphonesimulator \
  -configuration Release \
  -derivedDataPath build/DD/Build || \
  fail "Build for Simulator Failed"

#
# Run Tests
#
heading "Running Tests"

SIM_DEVICE="iPhone 7"
SIM_OS=`xcrun simctl list runtimes | grep iOS | awk '{print $2}' | tail -n 1`

rm -rf build/TestBundle
TEST_DERIVED_DATA_DIR="build/DD/Test"

xcb test \
  -scheme ZZZ_MOBIUS_ALL \
  -configuration Debug \
  -enableCodeCoverage YES \
  -resultBundlePath build/TestBundle \
  -derivedDataPath "$TEST_DERIVED_DATA_DIR" \
  -destination "platform=iOS Simulator,name=$SIM_DEVICE,OS=$SIM_OS" || \
  fail "Test Run Failed"

process_coverage -D "$TEST_DERIVED_DATA_DIR" -F ios
