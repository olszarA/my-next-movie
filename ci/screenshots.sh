#!/bin/bash
# Installs the built app on the simulator, walks through the steps in ci/screens.txt
# with AXe and saves a screenshot at every `shot`.
set -u
out=build/screens

# Runs a command, killed after $1 seconds, so one stuck step does not stop the rest.
limited() {
  local seconds=$1
  shift
  "$@" &
  local pid=$!
  ( sleep "$seconds"; kill -9 "$pid" 2>/dev/null ) &
  local watcher=$!
  wait "$pid"
  local status=$?
  kill "$watcher" 2>/dev/null
  return $status
}
mkdir -p "$out"
app=build/DerivedData/Build/Products/Debug-iphonesimulator/MyNextMovie.app
bundle=com.fwsoft.MyNextMovie

curl -sSL -o /tmp/axe.tar.gz \
  https://github.com/cameroncooke/AXe/releases/download/v2.0.4/AXe-macOS-v2.0.4-universal.tar.gz
mkdir -p /tmp/axe && tar -xzf /tmp/axe.tar.gz -C /tmp/axe
axe=$(find /tmp/axe -type f -name axe -perm -u+x | head -1)
echo "axe: $axe"

# The simulator was booted before the build and the tests ran on it.
echo "== boot $(date +%T)"
limited 60 xcrun simctl boot "$SIM_UDID" 2>/dev/null
limited 240 xcrun simctl bootstatus "$SIM_UDID" -b | tail -2
echo "== install $(date +%T)"
limited 240 xcrun simctl install "$SIM_UDID" "$app"
echo "== location $(date +%T)"
limited 30 xcrun simctl privacy "$SIM_UDID" grant location "$bundle" || true
limited 30 xcrun simctl location "$SIM_UDID" set 51.0983,17.0368 || true
echo "== launch $(date +%T)"
limited 90 xcrun simctl launch "$SIM_UDID" "$bundle"
sleep 10
echo "== steps $(date +%T)"

n=0
while IFS= read -r line || [ -n "$line" ]; do
  [ -z "$line" ] && continue
  case "$line" in \#*) continue ;; esac
  cmd=${line%% *}
  arg=${line#* }
  echo "> $line ($(date +%T))"
  case "$cmd" in
    shot)
      n=$((n + 1))
      name=$(printf '%02d-%s' "$n" "$arg")
      limited 30 xcrun simctl io "$SIM_UDID" screenshot "$out/$name.png" >/dev/null 2>&1
      limited 30 "$axe" describe-ui --udid "$SIM_UDID" > "$out/$name.json" 2>&1 || true
      ;;
    tap) limited 30 "$axe" tap --label "$arg" --udid "$SIM_UDID" || echo "tap failed: $arg" ;;
    tapid) limited 30 "$axe" tap --id "$arg" --udid "$SIM_UDID" || echo "tap failed: $arg" ;;
    tapxy) limited 30 "$axe" tap -x "${arg% *}" -y "${arg#* }" --udid "$SIM_UDID" || echo "tap failed: $arg" ;;
    type) limited 30 "$axe" type "$arg" --udid "$SIM_UDID" || echo "type failed: $arg" ;;
    key) limited 30 "$axe" key "$arg" --udid "$SIM_UDID" || echo "key failed: $arg" ;;
    swipe) limited 30 "$axe" gesture "$arg" --udid "$SIM_UDID" || echo "swipe failed: $arg" ;;
    wait) sleep "$arg" ;;
    relaunch)
      limited 30 xcrun simctl terminate "$SIM_UDID" "$bundle" || true
      limited 30 xcrun simctl launch "$SIM_UDID" "$bundle"
      sleep 5
      ;;
    *) echo "unknown step: $line" ;;
  esac
done < ci/screens.txt
