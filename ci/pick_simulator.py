# Prints the UDID of the newest available iPhone 17 simulator.
import json
import sys

devices = json.load(sys.stdin)["devices"]
best = None
for runtime, runtime_devices in devices.items():
    if ".iOS-" not in runtime:
        continue
    parts = runtime.split(".iOS-")[1].split("-")
    version = tuple(int(part) for part in parts if part.isdigit())
    for device in runtime_devices:
        print(runtime, device["name"], file=sys.stderr)
        if device["name"] == "iPhone 17" and device.get("isAvailable", True):
            if best is None or version > best[0]:
                best = (version, device["udid"])
if best is None:
    sys.exit("no iPhone 17 simulator")
print("picked", best, file=sys.stderr)
print(best[1])
