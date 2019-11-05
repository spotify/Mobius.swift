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

do_carthage_bootstrap() {
  mkdir -p build
  carthage bootstrap --platform iOS \
    --cache-builds --no-use-binaries \
    --log-path build/carthage.log

  if [ $? -ne 0 ]; then
    [[ "$IS_CI" == "1" ]] && dump_log "build/carthage.log"
    fail "Carthage bootstrap failed"
  fi
}
