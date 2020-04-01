#!/bin/bash

root=`dirname $0`
source "$root/../../helpers.sh"

workspace=$root/MobiusCocoaPodsTest.xcworkspace
platforms=(iOS)

heading "Preparing CocoaPods build"

pushd $root > /dev/null
pod install
success=$?
popd
if [ ! $success ]; then
    fail "Carthage update failed"
fi

for platform in ${platforms[@]}; do
    heading "Building for $platform using CocoaPods"
    scheme=MobiusCocoaPodsTest

    xcb -workspace $workspace -scheme $scheme || \
        fail "CocoaPods build for $platform failed"
done
