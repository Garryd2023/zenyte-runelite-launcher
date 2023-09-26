#!/bin/bash

set -e

PACKR_VERSION="runelite-1.7"
PACKR_HASH="f61c7faeaa364b6fa91eb606ce10bd0e80f9adbce630d2bae719aef78d45da61"

SIGNING_IDENTITY="F60F427F725F23E7224489A912A0D1661A129C48"

source .jdk-versions.sh

if ! [ -f mac_aarch64_jre.tar.gz ] ; then
    curl -Lo mac_aarch64_jre.tar.gz $MAC_AARCH64_LINK
fi

echo "$MAC_AARCH64_CHKSUM  mac_aarch64_jre.tar.gz" | shasum -c

# packr requires a "jdk" and pulls the jre from it - so we have to place it inside
# the jdk folder at jre/
if ! [ -d osx-aarch64-jdk ] ; then
    tar zxf mac_aarch64_jre.tar.gz
    mkdir osx-aarch64-jdk
    mv jdk-$MAC_AARCH64_VERSION-jre osx-aarch64-jdk/jre

    pushd osx-aarch64-jdk/jre
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
	packr/macos-aarch64-config.json

cp target/filtered-resources/Info.plist native-osx-aarch64/The CErver.app/Contents

echo Setting world execute permissions on The CErver
pushd native-osx-aarch64/The CErver.app
chmod g+x,o+x Contents/MacOS/The CErver
popd

codesign -f --entitlements osx/signing.entitlements --options runtime native-osx-aarch64/The CErver.app || true

# create-dmg exits with an error code due to no code signing, but is still okay
create-dmg native-osx-aarch64/The CErver.app native-osx-aarch64/ || true

mv native-osx-aarch64/The CErver\ *.dmg native-osx-aarch64/The CErver-aarch64.dmg

# Notarize app
if xcrun notarytool submit native-osx-aarch64/The CErver-aarch64.dmg --wait --keychain-profile "07c13e1cb5" ; then
    xcrun stapler staple native-osx-aarch64/The CErver-aarch64.dmg
fi
