#!/bin/bash

set -e

PACKR_VERSION="runelite-1.9"
PACKR_HASH="544efb4a88f561aa40a6dc9453d13a00231f10ed867f741ac7f6ded2757c1b8d"

source .jdk-versions.sh

if ! [ -f win-aarch64_jre.zip ] ; then
    curl -Lo win-aarch64_jre.zip $WIN_AARCH64_LINK
fi

echo "$WIN_AARCH64_CHKSUM win-aarch64_jre.zip" | sha256sum -c

# packr requires a "jdk" and pulls the jre from it - so we have to place it inside
# the jdk folder at jre/
if ! [ -d win-aarch64-jdk ] ; then
    unzip win-aarch64_jre.zip
    mkdir win-aarch64-jdk
    jlink \
      --compress 2 \
      --strip-debug \
      --no-header-files \
      --no-man-pages \
      --output win-aarch64-jdk/jre \
      --module-path jdk-$WIN_AARCH64_VERSION/jmods \
      --add-modules java.base \
      --add-modules java.compiler \
      --add-modules java.datatransfer \
      --add-modules java.desktop \
      --add-modules java.instrument \
      --add-modules java.logging \
      --add-modules java.management \
      --add-modules java.management.rmi \
      --add-modules java.naming \
      --add-modules java.net.http \
      --add-modules java.prefs \
      --add-modules java.rmi \
      --add-modules java.scripting \
      --add-modules java.se \
      --add-modules java.security.jgss \
      --add-modules java.security.sasl \
      --add-modules java.smartcardio \
      --add-modules java.sql \
      --add-modules java.sql.rowset \
      --add-modules java.transaction.xa \
      --add-modules java.xml \
      --add-modules java.xml.crypto \
      --add-modules jdk.accessibility \
      --add-modules jdk.charsets \
      --add-modules jdk.crypto.cryptoki \
      --add-modules jdk.crypto.ec \
      --add-modules jdk.crypto.mscapi \
      --add-modules jdk.dynalink \
      --add-modules jdk.httpserver \
      --add-modules jdk.internal.ed \
      --add-modules jdk.internal.le \
      --add-modules jdk.jdwp.agent \
      --add-modules jdk.jfr \
      --add-modules jdk.jsobject \
      --add-modules jdk.localedata \
      --add-modules jdk.management \
      --add-modules jdk.management.agent \
      --add-modules jdk.management.jfr \
      --add-modules jdk.naming.dns \
      --add-modules jdk.naming.ldap \
      --add-modules jdk.naming.rmi \
      --add-modules jdk.net \
      --add-modules jdk.pack \
      --add-modules jdk.scripting.nashorn \
      --add-modules jdk.scripting.nashorn.shell \
      --add-modules jdk.sctp \
      --add-modules jdk.security.auth \
      --add-modules jdk.security.jgss \
      --add-modules jdk.unsupported \
      --add-modules jdk.xml.dom \
      --add-modules jdk.zipfs
fi

if ! [ -f packr_${PACKR_VERSION}.jar ] ; then
    curl -Lo packr_${PACKR_VERSION}.jar \
        https://github.com/runelite/packr/releases/download/${PACKR_VERSION}/packr.jar
fi

echo "${PACKR_HASH}  packr_${PACKR_VERSION}.jar" | sha256sum -c

java -jar packr_${PACKR_VERSION}.jar \
    packr/win-aarch64-config.json

tools/rcedit-x64 native-win-aarch64/TheCErver.exe \
  --application-manifest packr/runelite.manifest \
  --set-icon runelite.ico

echo TheCErver.exe aarch64 sha256sum
sha256sum native-win-aarch64/TheCErver.exe

dumpbin //HEADERS native-win-aarch64/TheCErver.exe

# We use the filtered iss file
iscc target/filtered-resources/runeliteaarch64.iss