#!/usr/bin/env bash
# check.sh — the hosting clauses, asserted against the live identity.
#
# These are the same four clauses the census measures on 150 stores, applied to
# our own document: a JSON content-type, `max-age` of at least 60, a validator,
# and no redirect. A merchant fetches this document before it does anything, so
# a regression here is an identity outage rather than a broken page.
set -uo pipefail

host="${1:-https://agent.attainai.ai}"
path="${2:-/.well-known/ucp}"
url="${host}${path}"
fail=0

say() { printf '%-46s %s\n' "$1" "$2"; }
bad() { say "$1" "$2"; fail=1; }

# One request, no redirect following, because a 3xx on this path is itself a
# violation — following it would hide the thing being tested.
hdrs="$(curl -sS -o /tmp/agent-profile.body -D /tmp/agent-profile.head \
          --max-time 20 -A "ucpconform/0.1 (+profile check)" "$url" 2>&1)" || {
  bad "reachable" "curl failed: ${hdrs}"; }

status="$(awk 'NR==1{print $2}' /tmp/agent-profile.head 2>/dev/null)"
case "$status" in
  200) say "status 200" "ok" ;;
  3??) bad "no redirect" "got ${status} — the spec forbids 3xx on a profile endpoint" ;;
  *)   bad "status 200" "got ${status:-none}" ;;
esac

ctype="$(grep -i '^content-type:' /tmp/agent-profile.head | tr -d '\r' | cut -d' ' -f2- | head -1)"
case "$ctype" in
  application/json*) say "content-type application/json" "ok (${ctype})" ;;
  *)                 bad "content-type application/json" "got ${ctype:-none}" ;;
esac

cc="$(grep -i '^cache-control:' /tmp/agent-profile.head | tr -d '\r' | cut -d' ' -f2- | head -1)"
age="$(printf '%s' "$cc" | grep -oE 'max-age=[0-9]+' | cut -d= -f2 | head -1)"
if [ -n "${age:-}" ] && [ "$age" -ge 60 ]; then
  say "cache max-age >= 60" "ok (${age}s)"
else
  bad "cache max-age >= 60" "got ${cc:-no cache-control}"
fi

if grep -qiE '^(etag|last-modified):' /tmp/agent-profile.head; then
  say "validator present" "ok"
else
  bad "validator present" "no ETag or Last-Modified"
fi

if python3 - <<'PY'
import json, sys
try:
    doc = json.load(open("/tmp/agent-profile.body"))
except Exception as e:
    sys.exit("body is not JSON: %s" % e)
ucp = doc.get("ucp") or {}
missing = [k for k in ("version", "services", "payment_handlers") if k not in ucp]
sys.exit("ucp member missing: %s" % missing if missing else 0)
PY
then
  say "body is a valid profile" "ok"
else
  bad "body is a valid profile" "see above"
fi

echo
if [ "$fail" -ne 0 ]; then
  echo "check: FAIL — ${url}"
  exit 1
fi
echo "check: PASS — ${url}"
