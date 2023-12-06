#!/bin/bash

set -e

PACKR_VERSION="runelite-1.9"
PACKR_HASH="544efb4a88f561aa40a6dc9453d13a00231f10ed867f741ac7f6ded2757c1b8d"

source .jdk-versions.sh

if ! [ -f win64_jre.zip ] ; then
    curl -Lo win64_jre.zip $WIN64_LINK
fi

echo "$WIN64_CHKSUM win64_jre.zip" | sha256sum -c

# packr requires a "jdk" and pulls the jre from it - so we have to place it inside
# the jdk folder at jre/
if ! [ -d win64-jdk ] ; then
    unzip win64_jre.zip
    mkdir win64-jdk
    mv jdk-$WIN64_VERSION-jre win64-jdk/jre
fi

if ! [ -f packr_${PACKR_VERSION}.jar ] ; then
    curl -Lo packr_${PACKR_VERSION}.jar \
        https://github.com/runelite/packr/releases/download/${PACKR_VERSION}/packr.jar
fi

echo "${PACKR_HASH}  packr_${PACKR_VERSION}.jar" | sha256sum -c

java -jar packr_${PACKR_VERSION}.jar \
    packr/win-x64-config.json

tools/rcedit-x64 native-win64/TheNightmatez.exe \
  --application-manifest packr/runelite.manifest \
  --set-icon favicon.ico

echo TheNightmatez.exe 64bit sha256sum
sha256sum native-win64/TheNightmatez.exe

dumpbin //HEADERS native-win64/TheNightmatez.exe

# We use the filtered iss file
"C:\Program Files (x86)\Inno Setup 6\iscc.exe" target/filtered-resources/runelite.iss