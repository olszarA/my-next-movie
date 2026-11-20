#!/bin/bash
# Installs the built app on the simulator, walks through the steps in ci/screens.txt
# with AXe and saves a screenshot at every `shot`.
set -u
out=build/screens
mkdir -p "$out"
app=build/DerivedData/Build/Products/Debug-iphonesimulator/MyNextMovie.app
bundle=com.fwsoft.MyNextMovie

curl -sSL -o /tmp/axe.tar.gz \
  https://github.com/cameroncooke/AXe/releases/download/v2.0.4/AXe-macOS-v2.0.4-universal.tar.gz
mkdir -p /tmp/axe && tar -xzf /tmp/axe.tar.gz -C /tmp/axe
axe=$(find /tmp/axe -type f -name axe -perm -u+x | head -1)
echo "axe: $axe"

xcrun simctl boot "$SIM_UDID" 2>/dev/null
xcrun simctl bootstatus "$SIM_UDID" -b
xcrun simctl location "$SIM_UDID" set 51.0983,17.0368 || true
xcrun simctl privacy "$SIM_UDID" grant location "$bundle" || true
xcrun simctl install "$SIM_UDID" "$app"
xcrun simctl launch "$SIM_UDID" "$bundle"
sleep 6

n=0
while IFS= read -r line || [ -n "$line" ]; do
  [ -z "$line" ] && continue
  case "$line" in \#*) continue ;; esac
  cmd=${line%% *}
  arg=${line#* }
  echo "> $line"
  case "$cmd" in
    shot)
      n=$((n + 1))
      name=$(printf '%02d-%s' "$n" "$arg")
      xcrun simctl io "$SIM_UDID" screenshot "$out/$name.png" >/dev/null 2>&1
      "$axe" describe-ui --udid "$SIM_UDID" > "$out/$name.json" 2>&1 || true
      ;;
    tap) "$axe" tap --label "$arg" --udid "$SIM_UDID" || echo "tap failed: $arg" ;;
    tapid) "$axe" tap --id "$arg" --udid "$SIM_UDID" || echo "tap failed: $arg" ;;
    tapxy) "$axe" tap -x "${arg% *}" -y "${arg#* }" --udid "$SIM_UDID" || echo "tap failed: $arg" ;;
    type) "$axe" type "$arg" --udid "$SIM_UDID" || echo "type failed: $arg" ;;
    key) "$axe" key "$arg" --udid "$SIM_UDID" || echo "key failed: $arg" ;;
    swipe) "$axe" gesture "$arg" --udid "$SIM_UDID" || echo "swipe failed: $arg" ;;
    wait) sleep "$arg" ;;
    relaunch)
      xcrun simctl terminate "$SIM_UDID" "$bundle" || true
      xcrun simctl launch "$SIM_UDID" "$bundle"
      sleep 5
      ;;
    *) echo "unknown step: $line" ;;
  esac
done < ci/screens.txt
