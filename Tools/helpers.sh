#!/bin/bash

fail() {
  >&2 echo "error: $@"
  exit 1
}

has_command() {
  command -v "$1" >/dev/null 2>&1
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
