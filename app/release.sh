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

# Product analytics. The define below reads an empty string when POSTHOG_KEY
# is not exported in this shell, analytics then never starts, and the build
# is silently dark: Sentry still reports, so nothing looks wrong, and the
# funnel for everybody on that build is simply absent. Build 13 went to app
# review that way and sent PostHog nothing at all.
#
# So this refuses to build rather than shipping a build nobody can be
# counted in. Export the key, or say plainly that this one is meant to be
# dark with SOUL_NO_POSTHOG=1. Decision 286.
if [ -z "${POSTHOG_KEY:-}" ] && [ -z "${SOUL_NO_POSTHOG:-}" ]; then
  echo "POSTHOG_KEY is not set, so this build would reach nobody in the funnels."
  echo "Export it, or run again with SOUL_NO_POSTHOG=1 to build without it."
  exit 1
fi

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
