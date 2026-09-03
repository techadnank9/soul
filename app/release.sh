#!/bin/sh
# Builds the signed iOS archive and uploads it to App Store Connect, where it
# lands under TestFlight. Nothing here submits anything for App Store review.
#
# Run from anywhere:   app/release.sh
# Needs: Xcode signed in to the Soul Space team, and the version in
# pubspec.yaml raised since the last upload. Apple refuses a repeat.
set -eu
cd "$(dirname "$0")"
API="${SOUL_API:-https://soul-api-i6mr.onrender.com}"

echo "building against $API"
flutter build ipa --flavor soul --dart-define="SOUL_API=$API"

echo "uploading to App Store Connect"
xcodebuild -exportArchive \
  -archivePath build/ios/archive/Soul.xcarchive \
  -exportOptionsPlist ios/ExportOptions.plist \
  -exportPath build/ios/upload \
  -allowProvisioningUpdates \
  | grep -i "uploaded\|error\|succeeded\|failed" || true
