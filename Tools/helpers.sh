#!/bin/sh

heading() {
  MAG='\033[0;35m'
  CLR='\033[0m'
  echo ""
  echo "${MAG}** $@ **${CLR}"
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

do_carthage_bootstrap() {
  carthage bootstrap --platform iOS \
    --cache-builds --no-use-binaries || \
    fail "Carthage bootstrap failed"
}
