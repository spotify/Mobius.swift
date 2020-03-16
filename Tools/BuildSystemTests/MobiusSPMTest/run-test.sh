#!/bin/bash

root=`dirname $0`
source "$root/../../helpers.sh"

project=$root/MobiusSPMTest.xcodeproj
platforms=(iOS macOS tvOS watchOS)

for platform in ${platforms[@]}; do
    heading "Building for $platform using Swift Package Manager"
    scheme=MobiusSPMTest_$platform

    xcb -project $project -scheme $scheme || \
        fail "Swift Package Manager build for $platform failed"
done
