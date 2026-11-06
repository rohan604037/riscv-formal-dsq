#!/usr/bin/env bash
# Print the latest OSS CAD Suite linux-x64 release asset name, size and URL.
curl -s https://api.github.com/repos/YosysHQ/oss-cad-suite-build/releases/latest |
  python3 -c '
import json,sys
r=json.load(sys.stdin)
for a in r["assets"]:
    if "linux-x64" in a["name"]:
        print(a["name"], round(a["size"]/1e6), "MB", a["browser_download_url"])
'
