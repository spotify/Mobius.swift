#!/usr/bin/env sh

XCODE_DIR=$HOME'/Library/Developer/Xcode/Templates/File Templates/Mobius'
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ARGUMENTS=$@

print() {
    if [[ $ARGUMENTS != *--quiet* ]]; then
        echo "$1"
    fi
}

removeTemplates() {
    if [ -d "$XCODE_DIR" ]; then
        rm -R "$XCODE_DIR"
    fi
}

copyTemplates() {
    mkdir -p "$XCODE_DIR"

    cp -a $SCRIPT_DIR/src/*.xctemplate "$XCODE_DIR"
}

printHelp() {
    echo "Usage: $0 [--install remove]"
}

if [[ $ARGUMENTS == *--remove* ]]; then
    removeTemplates
    echo "Done!"
elif [[ $ARGUMENTS == *--install* ]]; then
    removeTemplates
    copyTemplates
    echo "Done!"
else
    printHelp
fi
