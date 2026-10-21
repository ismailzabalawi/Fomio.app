#!/usr/bin/env bash
# Read-only verification of the deployed discourse-fomio-app-locales endpoints, schema 2 (plugin v0.3.0), uncompressed
# and compressed. Adapted from the 2026-10-16 schema-1 script.
#
#   docs/validation/2026-10-21-site-texts/verify-live-catalogs.sh [base-url]
#
# Anonymous checks always run. Member checks run only when FOMIO_MEMBER_API_KEY and FOMIO_MEMBER_USERNAME
# are set in the environment (a per-user User API key, never an admin key). The key is sent only as a
# request header and is never printed; the member's username is printed only as "present"/"absent".
# Exit status is non-zero when any check fails.
set -uo pipefail

BASE="${1:-https://meta.fomio.app}"
FAIL=0
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT
pass() { printf 'PASS  %s\n' "$1"; }
fail() { printf 'FAIL  %s\n' "$1"; FAIL=1; }

# get <label> <path> [extra curl args...] -> writes $TMP/<label>.{h,b}; prints status
get() {
  local label="$1" path="$2"; shift 2
  curl -s -D "$TMP/$label.h" -o "$TMP/$label.b" "$@" "$BASE$path"
  awk 'toupper($1) ~ /^HTTP/ {code=$2} END {print code}' "$TMP/$label.h"
}
header() { grep -i "^$2:" "$TMP/$1.h" | tail -1 | cut -d' ' -f2- | tr -d '\r'; }

echo "Base: $BASE   $(date -u +%FT%TZ)"
echo "Generator: $(curl -s "$BASE/" | grep -o 'version [0-9a-f]\{40\}' | head -1)"
[ "$(curl -s "$BASE/srv/status")" = "ok" ] && pass "/srv/status ok" || fail "/srv/status not ok"

check_catalogs() {
  local who="$1"; shift
  local s
  s=$(get "$who-index" /fomio/app-locales/2/index.json "$@")
  [ "$s" = 200 ] && pass "$who index 200" || fail "$who index status $s"
  python3 -I -c 'import json,sys; d=json.load(open(sys.argv[1])); print("      locales:", [ (l["locale"], l["complete"]) for l in d["locales"] ], "default_locale:", d["default_locale"])' "$TMP/$who-index.b" 2>/dev/null || fail "$who index is not JSON"
  [ -z "$(header "$who-index" X-Discourse-Username)" ] && pass "$who index has no X-Discourse-Username" || fail "$who index names a member"
  case "$(header "$who-index" Cache-Control)" in *public*) pass "$who index Cache-Control public";; *) fail "$who index Cache-Control: $(header "$who-index" Cache-Control)";; esac

  s=$(get "$who-en" /fomio/app-locales/2/en.json "$@")
  [ "$s" = 200 ] && pass "$who en 200" || fail "$who en status $s"
  local etag; etag="$(header "$who-en" ETag)"
  [ -n "$etag" ] && pass "$who en ETag $etag" || fail "$who en has no ETag"
  [ -z "$(header "$who-en" X-Discourse-Username)" ] && pass "$who en has no X-Discourse-Username" || fail "$who en names a member"
  case "$(header "$who-en" Cache-Control)" in *public*) pass "$who en Cache-Control public";; *) fail "$who en Cache-Control: $(header "$who-en" Cache-Control)";; esac
  python3 -I -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["locale"]=="en" and d["complete"] and d["schema"]==2 and d["fallback"]==[]; c=d["coverage"]; print("      en messages:", len(d["messages"]), "revision:", d["revision"], "coverage:", {k: c.get(k) for k in ("total","override","outdated_override")}, "terminology enabled:", c.get("terminology",{}).get("enabled"))' "$TMP/$who-en.b" 2>/dev/null || fail "$who en body is not a complete schema-2 catalog"

  s=$(get "$who-en304" /fomio/app-locales/2/en.json -H "If-None-Match: $etag" "$@")
  [ "$s" = 304 ] && pass "$who en conditional 304" || fail "$who en conditional status $s"
  [ -z "$(header "$who-en304" X-Discourse-Username)" ] && pass "$who 304 has no X-Discourse-Username" || fail "$who 304 names a member"

  # Compressed, as browsers and iOS URLSession request it: the ETag reaches the client weak (W/"…"), and sending that
  # back must still revalidate (304). Added 2026-10-17 after v0.1.0 answered 200 here.
  local doc
  for doc in index en; do
    s=$(get "$who-$doc-z" "/fomio/app-locales/2/$doc.json" --compressed "$@")
    local zetag; zetag="$(header "$who-$doc-z" ETag)"
    [ "$s" = 200 ] && pass "$who $doc compressed 200 ($(header "$who-$doc-z" Content-Encoding), ETag $zetag)" || fail "$who $doc compressed status $s"
    case "$zetag" in W/*) ;; *) echo "NOTE  $who $doc compressed ETag is not weak ($zetag): this response was not compressed in transit";; esac
    case "$(header "$who-$doc-z" Cache-Control)" in *public*) pass "$who $doc compressed Cache-Control public";; *) fail "$who $doc compressed Cache-Control: $(header "$who-$doc-z" Cache-Control)";; esac
    s=$(get "$who-$doc-z304" "/fomio/app-locales/2/$doc.json" --compressed -H "If-None-Match: $zetag" "$@")
    [ "$s" = 304 ] && pass "$who $doc compressed conditional with returned ETag $zetag → 304" || fail "$who $doc compressed conditional with returned ETag $zetag → $s (expected 304)"
    [ -z "$(header "$who-$doc-z" X-Discourse-Username)$(header "$who-$doc-z304" X-Discourse-Username)" ] && pass "$who $doc compressed responses have no X-Discourse-Username" || fail "$who $doc compressed response names a member"
  done

  for path in /fomio/app-locales/2/xx.json /fomio/app-locales/1/index.json /fomio/app-locales/1/en.json /fomio/app-locales/3/index.json /fomio/app-locales/2/AR.json /fomio/app-locales/2/ar.json; do
    s=$(get "$who-neg" "$path" "$@"); [ "$s" = 404 ] && pass "$who $path 404" || fail "$who $path status $s"
  done
}

check_catalogs anonymous
cp "$TMP/anonymous-en.b" "$TMP/anon-en.json"
# Live English must equal the app's bundled English (no en overrides exist yet).
APP_EN="$(cd "$(dirname "$0")/../../.." && pwd)/Fomio/Resources/Localization/fomio-catalog-en.json"
python3 -I -c 'import json,sys; a=json.load(open(sys.argv[1]))["messages"]; b=json.load(open(sys.argv[2]))["messages"]; d=[k for k in set(a)|set(b) if a.get(k)!=b.get(k)]; print("      differing keys:", len(d), sorted(d)[:5]); sys.exit(1 if d else 0)' "$TMP/anon-en.json" "$APP_EN" && pass "live en messages equal the app's bundled English" || fail "live en differs from the app's bundled English"

if [ -n "${FOMIO_MEMBER_API_KEY:-}" ] && [ -n "${FOMIO_MEMBER_USERNAME:-}" ]; then
  check_catalogs member -H "User-Api-Key: $FOMIO_MEMBER_API_KEY"
  cmp -s "$TMP/anon-en.json" "$TMP/member-en.b" && pass "member en body identical to anonymous" || fail "member en body differs from anonymous"
  grep -q -F "$FOMIO_MEMBER_USERNAME" "$TMP/member-index.b" "$TMP/member-en.b" && fail "member username present in a body" || pass "member username absent from bodies"
else
  echo "SKIP  member checks (set FOMIO_MEMBER_API_KEY and FOMIO_MEMBER_USERNAME to run them)"
fi
exit $FAIL
