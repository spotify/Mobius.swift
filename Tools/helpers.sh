#!/bin/bash

heading() {
  MAG='\033[0;35m'
  CLR='\033[0m'
  echo ""
  echo -e "${MAG}** $@ **${CLR}"
  echo ""
}

fail() {
  >&2 echo "error: $@"
  exit 1
}

has_command() {
  command -v "$1" >/dev/null 2>&1
}

xcb() {
  export NSUnbufferedIO=YES
  set -o pipefail && xcodebuild \
    -UseSanitizedBuildSystemEnvironment=YES \
    CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY= \
    "$@" | xcpretty
}

dump_log() {
  heading "Dumping $1"
  cat "$1"
  echo ""
}

patch_to_legacy_build_system() {
  /usr/libexec/PlistBuddy -c "Delete :BuildSystemType" "$1" 2>/dev/null
  /usr/libexec/PlistBuddy -c "Add :BuildSystemType string \"Original\"" "$1"
}

do_carthage_bootstrap() {
  mkdir -p build
  carthage checkout

  carthage build --platform iOS \
    --cache-builds --no-use-binaries \
    --log-path build/carthage.log \
    --use-xcframeworks

  if [ $? -ne 0 ]; then
    [[ "$IS_CI" == "1" ]] && dump_log "build/carthage.log"
    fail "Carthage bootstrap failed"
  fi
}

process_coverage() {
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
  build/codecov.sh -X xcodellvm $CODECOV_EXTRA "$@"
}

if [[ -n "$GITHUB_WORKFLOW" ]]; then
  echo "CI Detected"
  export IS_CI=1
fi
