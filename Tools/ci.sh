#!/bin/sh

# Source Helper Functions
source "$(dirname "$0")/helpers.sh"

# Only install tools when running on travis
if [ -n "$TRAVIS_BUILD_ID" ]; then
  heading "Installing Tools"
  brew install carthage swiftlint
  gem install xcpretty
fi

has_command carthage || fail "Carthage must be installed"
has_command swiftlint || fail "SwiftLint must be installed"
has_command xcpretty || fail "xcpretty must be installed"

#
# Fail fast with swiftlint
#
heading "Linting"

swiftlint lint --no-cache --strict || \
  fail "swiftlint failed"

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
  -configuration Release || \
  fail "Build for Device Failed"

heading "Building for Release"
xcb build \
  -scheme ZZZ_MOBIUS_ALL \
  -sdk iphonesimulator \
  -configuration Release || \
  fail "Build for Simulator Failed"

#
# Run Tests
#
heading "Running Tests"

SIM_DEVICE="iPhone 6"
SIM_OS=`xcrun simctl list runtimes | grep iOS | awk '{print $2}' | tail -n 1`

rm -rf build/TestBundle

xcb test \
  -scheme ZZZ_MOBIUS_ALL \
  -sdk iphonesimulator \
  -configuration Debug \
  -enableCodeCoverage YES \
  -resultBundlePath build/TestBundle \
  -destination "platform=iOS Simulator,name=$SIM_DEVICE,OS=$SIM_OS" || \
  fail "Test Run Failed"

#
# Collect Code Coverage
#
heading "Pushing Coverage to Codecov"

if [ "$SKIP_COVERAGE" == "1" ]; then
  echo "Skipping (SKIP_COVERAGE == 1)"
  exit 0
fi

curl -s https://codecov.io/bash > build/codecov.sh
chmod +x build/codecov.sh
if [ -z "$TRAVIS_BUILD_ID" ]; then
  CODECOV_EXTRA="-d"  # dry-run
fi

# Silently fail
build/codecov.sh -D build/DerivedData -X xcodellvm $CODECOV_EXTRA

