import json
import sys

with open(sys.argv[1]) as summary_file:
    summary = json.load(summary_file)
keys = ["result", "totalTestCount", "passedTests", "failedTests", "skippedTests"]
print({key: summary.get(key) for key in keys})
for failure in summary.get("testFailures", []):
    print("FAILED:", failure.get("testIdentifierString"), "-", failure.get("failureText"))
