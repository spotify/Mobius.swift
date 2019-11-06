#!/bin/bash

# Source Helper Functions
source "$(dirname "$0")/helpers.sh"

# Copy umbrella scheme to the xcschemes directory. 
# We don't want to check it in otherwise Carthage also builds it needlessly.
cp "$(dirname "$0")/ZZZ_MOBIUS_ALL.xcscheme" "$(dirname "$0")/../Mobius.xcodeproj/xcshareddata/xcschemes"

# Only install tools when running on travis
if [[ -n "$TRAVIS_BUILD_ID" || -n "$GITHUB_WORKFLOW" ]]; then
  heading "Installing Tools"
  brew install carthage swiftlint
  gem install xcpretty
  export IS_CI=1
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

# re-enable below when there is a solution to carthage issue w/ nimble:
# https://github.com/Quick/Nimble/issues/702

# until then using SPM to unblock CI:

swift test --enable-code-coverage || fail "SPM Test Failed"

# h4x to trick codecov
for bundle in .build/x86_64-apple-macosx/debug/*.xctest ; do
  parent="$(dirname "$bundle")"
  ln -sf "$PWD/$bundle" "${parent}/codecov"
done

TEST_DERIVED_DATA_DIR=".build/x86_64-apple-macosx/debug"

# DISABLED CI BEGIN

# #
# # Bootstrap with Carthage
# #
# heading "Bootstrapping Carthage"
# do_carthage_bootstrap

# #
# # Build frameworks and libraries in release mode
# #
# heading "Building for Device"
# xcb build \
#   -scheme ZZZ_MOBIUS_ALL \
#   -destination generic/platform=iOS \
#   -configuration Release \
#   -derivedDataPath build/DD/Build || \
#   fail "Build for Device Failed"

# heading "Building for Simulator"
# xcb build \
#   -scheme ZZZ_MOBIUS_ALL \
#   -sdk iphonesimulator \
#   -configuration Release \
#   -derivedDataPath build/DD/Build || \
#   fail "Build for Simulator Failed"

# #
# # Run Tests
# #
# heading "Running Tests"

# SIM_DEVICE="iPhone 7"
# SIM_OS=`xcrun simctl list runtimes | grep iOS | awk '{print $2}' | tail -n 1`

# rm -rf build/TestBundle
# TEST_DERIVED_DATA_DIR="build/DD/Test"

# xcb test \
#   -scheme ZZZ_MOBIUS_ALL \
#   -configuration Debug \
#   -enableCodeCoverage YES \
#   -resultBundlePath build/TestBundle \
#   -derivedDataPath "$TEST_DERIVED_DATA_DIR" \
#   -destination "platform=iOS Simulator,name=$SIM_DEVICE,OS=$SIM_OS" || \
#   fail "Test Run Failed"

# DISABLED CI END

#
# CODECOV
#

# output a bunch of stuff that codecov might recognize
if [[ -n "$GITHUB_WORKFLOW" ]]; then
  PR_CANDIDATE=`echo "$GITHUB_REF" | egrep -o "pull/\d+" | egrep -o "\d+"`
  [[ -n "$PR_CANDIDATE" ]] && export VCS_PULL_REQUEST="$PR_CANDIDATE"
  export CI_BUILD_ID="$RUNNER_TRACKING_ID"
  export CI_JOB_ID="$RUNNER_TRACKING_ID"
  export CODECOV_SLUG="$GITHUB_REPOSITORY"
  export GIT_BRANCH="$GITHUB_REF"
  export GIT_COMMIT="$GITHUB_SHA"
  export VCS_BRANCH_NAME="$GITHUB_REF"
  export VCS_COMMIT_ID="$GITHUB_SHA"
  export VCS_SLUG="$GITHUB_REPOSITORY"
fi

mkdir -p build
curl -sfL https://codecov.io/bash > build/codecov.sh
chmod +x build/codecov.sh
[[ "$IS_CI" == "1" ]] || CODECOV_EXTRA="-d"
build/codecov.sh -D "$TEST_DERIVED_DATA_DIR" -X xcodellvm $CODECOV_EXTRA
