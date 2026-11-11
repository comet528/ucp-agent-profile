#!/usr/bin/env bash
# publish.sh — one source, three paths.
#
# The identity document is ucp/agent/<release>.json. `.well-known/ucp` is the
# path the spec names and `latest.json` is the alias; both are copies so they
# cannot drift. Run ./check.sh after pushing: a wrong publish is cached for ten
# minutes.
set -euo pipefail

release="${1:-2026-08-25}"
src="ucp/agent/${release}.json"

if [ ! -f "$src" ]; then
  echo "publish: no such release file: $src" >&2
  exit 1
fi

python3 - "$src" <<'PY'
import json, sys
src = sys.argv[1]
doc = json.load(open(src))
version = doc.get("ucp", {}).get("version")
if not version:
    sys.exit("publish: %s has no ucp.version" % src)
want = "ucp/agent/%s.json" % version
if src != want:
    sys.exit("publish: %s declares version %s; expected the file to be named %s" % (src, version, want))
PY

cp "$src" .well-known/ucp
cp "$src" ucp/agent/latest.json
echo "publish: $src -> .well-known/ucp, ucp/agent/latest.json"
