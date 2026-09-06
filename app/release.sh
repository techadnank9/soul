#!/bin/sh
# Builds the signed iOS archive and uploads it to App Store Connect, where it
# lands under TestFlight. Nothing here submits anything for App Store review.
#
# Run from anywhere:   app/release.sh
# Needs: Xcode signed in to the Soul Space team.
#
# The version stays at 0.2.0 and the build number goes up by one, here,
# every time. Apple refuses a repeat of the same pair, and raising the
# version instead left TestFlight with a list of thirteen versions holding
# one build each, which is a menu to scroll rather than a thing to test.
# 0.2.0 because it is above every version already uploaded, and App Store
# Connect will not take a version below the newest one it has.
set -eu
cd "$(dirname "$0")"
API="${SOUL_API:-https://soul-api-i6mr.onrender.com}"
# Product analytics, off in any build made without it. Export POSTHOG_KEY
# before running this, or put it in the shell profile on the release Mac.

version=$(grep '^version:' pubspec.yaml | sed 's/version: *//')
name=${version%%+*}
build=${version##*+}
next=$((build + 1))
sed -i '' "s/^version: .*/version: $name+$next/" pubspec.yaml
echo "building $name build $next against $API"

flutter build ipa --flavor soul \
  --dart-define="SOUL_API=$API" \
  --dart-define="SOUL_BUILD=$name ($next)" \
  --dart-define="POSTHOG_KEY=${POSTHOG_KEY:-}"
# The dart define above is optional now: a release build defaults to Render.

echo "uploading to App Store Connect"
xcodebuild -exportArchive \
  -archivePath build/ios/archive/Soul.xcarchive \
  -exportOptionsPlist ios/ExportOptions.plist \
  -exportPath build/ios/upload \
  -allowProvisioningUpdates \
  | grep -i "uploaded\|error\|succeeded\|failed" || true
