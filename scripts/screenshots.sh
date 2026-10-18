#!/bin/bash
set -euo pipefail

project_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_root"
output="$project_root/build/Screenshots"
mkdir -p "$output"
simulator_id="${SCREENSHOT_SIMULATOR_ID:-}"
created_simulator=false

cleanup() {
  if [ "$created_simulator" = true ]; then
    xcrun simctl shutdown "$simulator_id" >/dev/null 2>&1 || true
    xcrun simctl delete "$simulator_id" >/dev/null 2>&1 || true
  else
    xcrun simctl status_bar "$simulator_id" clear >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

if [ -z "$simulator_id" ]; then
  runtime_id="$(xcrun simctl list runtimes --json | python3 -c '
import json, sys
runtimes = [r for r in json.load(sys.stdin)["runtimes"]
            if r.get("isAvailable") and r["identifier"].startswith("com.apple.CoreSimulator.SimRuntime.iOS-")
            and int(r["version"].split(".")[0]) >= 26]
if not runtimes:
    sys.exit("No available iOS 26+ simulator runtime. Install one in Xcode Settings > Components.")
print(max(runtimes, key=lambda r: tuple(map(int, r["version"].split("."))))["identifier"])
')"
  simulator_id="$(xcrun simctl create 'Devisen Screenshots' com.apple.CoreSimulator.SimDeviceType.iPhone-17 "$runtime_id")"
  created_simulator=true
fi

# An explicitly supplied simulator may already be booted.
xcrun simctl boot "$simulator_id" 2>/dev/null || true
xcrun simctl bootstatus "$simulator_id" -b
xcrun simctl status_bar "$simulator_id" override --time '9:41' --dataNetwork wifi --wifiMode active --wifiBars 3 --batteryState charged --batteryLevel 100

rm -rf "$output/Results.xcresult" "$output/Attachments"
xcodebuild test \
  -project Currency.xcodeproj \
  -scheme Screenshots \
  -configuration Debug \
  -destination "platform=iOS Simulator,id=$simulator_id" \
  -derivedDataPath "$output/DerivedData" \
  -resultBundlePath "$output/Results.xcresult" \
  -parallel-testing-enabled NO \
  -test-timeouts-enabled YES \
  -default-test-execution-time-allowance 600 \
  -maximum-test-execution-time-allowance 600 \
  CODE_SIGNING_ALLOWED=NO DEVELOPMENT_TEAM= ONLY_ACTIVE_ARCH=YES

xcrun xcresulttool export attachments \
  --path "$output/Results.xcresult" \
  --output-path "$output/Attachments"
python3 scripts/publish-screenshots.py "$output/Attachments"
