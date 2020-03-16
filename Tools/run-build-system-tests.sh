#!/bin/bash

set -e

source `dirname $0`/helpers.sh
tests=Tools/BuildSystemTests/*/run-test.sh

for test_script in $tests; do
    $test_script
done
