#!/usr/bin/env bash
# Records the App Review walkthrough (HackDifferentUITests/ReviewRecording) signed in with an App Review code against
# production.
#
#   REVIEW_CODE=XXXX-XXXX-XXXX-XXXX ios/Scripts/review-recording.sh            # simulator, records an .mp4
#   REVIEW_CODE=XXXX-XXXX-XXXX-XXXX DEVICE=1 ios/Scripts/review-recording.sh   # the plugged-in iPhone
#
# Simulator: SIMULATOR (default "iPhone 17 Pro") picks it, LOCATION=lat,lon sets its location (default Salt Lake City,
# near 801 Labs), and OUT is the video (default ~/Desktop/hack-different-recording/review-sim-<time>.mp4).
#
# Device: DEVICE=1 uses the only connected iPhone, DEVICE=<udid or name> picks one. It must be unlocked, in Developer
# Mode and trusted by this Mac. The test waits START_DELAY seconds (default 15) on the home screen first: start the
# iPhone's Screen Recording from Control Center then, and stop it after the test ends. The video lands in Photos.
#
# PACE (default 1) slows every pause; EVENT, SPACE and ROOM pick what to open by name; OPEN_LINKS=0 skips opening
# Reply on Discord, Terms and Privacy in Safari. Nothing is posted, reported, blocked or deleted.
set -euo pipefail

: "${REVIEW_CODE:?Set REVIEW_CODE to the Hack Different App Review code (console Settings > App Review)}"
repo="$(cd "$(dirname "$0")/.." && pwd)"

# Exported, not passed as arguments: xcodebuild forwards TEST_RUNNER_* to the runner and prints build settings.
export TEST_RUNNER_HACKDIFFERENT_UITEST_REVIEW_CODE="$REVIEW_CODE"
for name in PACE EVENT SPACE ROOM OPEN_LINKS; do
  if [[ -n "${!name:-}" ]]; then export "TEST_RUNNER_HACKDIFFERENT_UITEST_$name=${!name}"; fi
done

run_test() {
  xcodebuild test -project "$repo/HackDifferent.xcodeproj" -scheme "HackDifferent Screenshots" \
    -destination "$1" -allowProvisioningUpdates \
    -only-testing:HackDifferentUITests/ReviewRecording/testReviewWalkthrough
}

if [[ -n "${DEVICE:-}" ]]; then
  json="$(mktemp)"
  xcrun devicectl list devices --json-output "$json" >/dev/null
  udid="$(DEVICE="$DEVICE" python3 - "$json" <<'PY'
import json, os, sys
want = os.environ["DEVICE"]
devices = [d for d in json.load(open(sys.argv[1]))["result"]["devices"]
           if d.get("hardwareProperties", {}).get("platform") == "iOS"
           and d.get("connectionProperties", {}).get("tunnelState") != "unavailable"]
if want != "1":
    devices = [d for d in devices if want in (d["hardwareProperties"].get("udid"), d["deviceProperties"].get("name"))]
if len(devices) != 1:
    sys.exit(f"Found {len(devices)} matching iPhones; plug one in or pass DEVICE=<udid or name>")
print(devices[0]["hardwareProperties"]["udid"])
PY
)"
  rm -f "$json"
  export TEST_RUNNER_HACKDIFFERENT_UITEST_START_DELAY="${START_DELAY:-15}"
  echo "Start the iPhone's Screen Recording when it shows the home screen (${TEST_RUNNER_HACKDIFFERENT_UITEST_START_DELAY}s)."
  run_test "platform=iOS,id=$udid"
  echo "Done: stop the iPhone's Screen Recording; the video is in Photos."
  exit 0
fi

name="${SIMULATOR:-iPhone 17 Pro}"
udid="$(xcrun simctl list devices available | grep -F "    $name (" | head -1 | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/')"
[[ -n "$udid" ]] || { echo "No available simulator named $name (xcrun simctl list devices)" >&2; exit 1; }
out="${OUT:-$HOME/Desktop/hack-different-recording/review-sim-$(date +%Y%m%d-%H%M%S).mp4}"
mkdir -p "$(dirname "$out")"

xcrun simctl boot "$udid" 2>/dev/null || true
xcrun simctl bootstatus "$udid" -b >/dev/null
xcrun simctl status_bar "$udid" override --time 9:41 --batteryState charged --batteryLevel 100 \
  --cellularBars 4 --wifiBars 3 || true
xcrun simctl location "$udid" set "${LOCATION:-40.7608,-111.8910}" || true
export TEST_RUNNER_HACKDIFFERENT_UITEST_START_DELAY="${START_DELAY:-3}"

xcrun simctl io "$udid" recordVideo --codec h264 --force "$out" &
recorder=$!
trap 'kill -INT $recorder 2>/dev/null; wait $recorder 2>/dev/null || true' EXIT
status=0
run_test "platform=iOS Simulator,id=$udid" || status=$?
kill -INT "$recorder"; wait "$recorder" 2>/dev/null || true
trap - EXIT
echo "Recording: $out"
exit "$status"
