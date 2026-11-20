# Prints the UDID of the newest available iPhone 17 simulator.
import json
import sys

devices = json.load(sys.stdin)["devices"]
best = None
for runtime, runtime_devices in devices.items():
    if ".iOS-" not in runtime:
        continue
    version = tuple(int(part) for part in runtime.split(".iOS-")[1].split("-"))
    for device in runtime_devices:
        if device["name"] == "iPhone 17" and device.get("isAvailable", True):
            if best is None or version > best[0]:
                best = (version, device["udid"])
if best is None:
    sys.exit("no iPhone 17 simulator")
print(best[1])
