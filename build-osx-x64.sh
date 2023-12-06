#!/bin/bash

set -e

PACKR_VERSION="runelite-1.7"
PACKR_HASH="f61c7faeaa364b6fa91eb606ce10bd0e80f9adbce630d2bae719aef78d45da61"

SIGNING_IDENTITY="5D5DFA571FE608EF2B1A6B4F1D9EF2B3"

source .jdk-versions.sh

if ! [ -f mac64_jre.tar.gz ] ; then
    curl -Lo mac64_jre.tar.gz $MAC_AMD64_LINK
fi

echo "$MAC_AMD64_CHKSUM  mac64_jre.tar.gz" | shasum -c

# packr requires a "jdk" and pulls the jre from it - so we have to place it inside
# the jdk folder at jre/
if ! [ -d osx-jdk ] ; then
    tar zxf mac64_jre.tar.gz
    mkdir osx-jdk
    mv jdk-$MAC_AMD64_VERSION-jre osx-jdk/jre

    pushd osx-jdk/jre
    # Move JRE out of Contents/Home/
    mv Contents/Home/* .
    # Remove unused leftover folders
    rm -rf Contents
    popd
fi

if ! [ -f packr_${PACKR_VERSION}.jar ] ; then
    curl -Lo packr_${PACKR_VERSION}.jar \
        https://github.com/runelite/packr/releases/download/${PACKR_VERSION}/packr.jar
fi

echo "${PACKR_HASH}  packr_${PACKR_VERSION}.jar" | shasum -c

java -jar packr_${PACKR_VERSION}.jar \
    packr/macos-x64-config.json

cp target/filtered-resources/Info.plist native-osx/TheNightmatez.app/Contents

echo Setting world execute permissions on TheNightmatez
pushd native-osx/TheNightmatez.app
chmod g+x,o+x Contents/MacOS/TheNightmatez
popd

codesign -f --entitlements osx/signing.entitlements --options runtime native-osx/TheNightmatez.app || true

# create-dmg exits with an error code due to no code signing, but is still okay
# note we use Adam-/create-dmg as upstream does not support UDBZ
create-dmg native-osx/TheNightmatez.app native-osx/ || true

mv native-osx/TheNightmatez\ *.dmg native-osx/TheNightmatez-x64.dmg

#if ! hdiutil imageinfo native-osx/TheNightmatez-x64.dmg | grep -q "Format: UDBZ" ; then
#    echo "Format of resulting dmg was not UDBZ, make sure your create-dmg has support for --format"
#    exit 1
#fi

# Notarize app
if xcrun notarytool submit native-osx/TheNightmatez-x64.dmg --wait --keychain-profile "07c13e1cb5" ; then
    xcrun stapler staple native-osx/TheNightmatez-x64.dmg
fi
