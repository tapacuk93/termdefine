#!/bin/bash
# Compiles the sources and assembles TermDefine.app in ./build.
set -euo pipefail

DIR="$(cd "$(dirname "$0")" && pwd)"
APP="$DIR/build/TermDefine.app"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$DIR/Resources/Info.plist" "$APP/Contents/Info.plist"

echo "Compiling…"
swiftc \
    -O \
    -swift-version 5 \
    -framework AppKit \
    -framework ApplicationServices \
    -framework CoreServices \
    -o "$APP/Contents/MacOS/TermDefine" \
    "$DIR"/Sources/*.swift

codesign --force --sign - --identifier com.oeaio.termdefine "$APP" >/dev/null 2>&1 \
    || echo "warning: ad-hoc codesign failed"

# NB: do not `tccutil reset Accessibility` here. The stable --identifier above is enough for
# macOS to keep honouring the existing grant across rebuilds; resetting it every build just
# forces a re-grant and leaves the app deaf until someone notices.
echo "Built $APP"
