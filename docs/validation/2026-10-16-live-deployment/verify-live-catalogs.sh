#!/usr/bin/env bash
# Read-only verification of the deployed discourse-fomio-app-locales endpoints.
#
#   docs/validation/2026-10-16-live-deployment/verify-live-catalogs.sh [base-url]
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
  s=$(get "$who-index" /fomio/app-locales/1/index.json "$@")
  [ "$s" = 200 ] && pass "$who index 200" || fail "$who index status $s"
  python3 -I -c 'import json,sys; d=json.load(open(sys.argv[1])); print("      locales:", [ (l["locale"], l["complete"]) for l in d["locales"] ], "default_locale:", d["default_locale"])' "$TMP/$who-index.b" 2>/dev/null || fail "$who index is not JSON"
  [ -z "$(header "$who-index" X-Discourse-Username)" ] && pass "$who index has no X-Discourse-Username" || fail "$who index names a member"
  case "$(header "$who-index" Cache-Control)" in *public*) pass "$who index Cache-Control public";; *) fail "$who index Cache-Control: $(header "$who-index" Cache-Control)";; esac

  s=$(get "$who-en" /fomio/app-locales/1/en.json "$@")
  [ "$s" = 200 ] && pass "$who en 200" || fail "$who en status $s"
  local etag; etag="$(header "$who-en" ETag)"
  [ -n "$etag" ] && pass "$who en ETag $etag" || fail "$who en has no ETag"
  [ -z "$(header "$who-en" X-Discourse-Username)" ] && pass "$who en has no X-Discourse-Username" || fail "$who en names a member"
  case "$(header "$who-en" Cache-Control)" in *public*) pass "$who en Cache-Control public";; *) fail "$who en Cache-Control: $(header "$who-en" Cache-Control)";; esac
  python3 -I -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["locale"]=="en" and d["complete"] and d["schema"]==1; print("      en messages:", len(d["messages"]), "revision:", d["revision"])' "$TMP/$who-en.b" 2>/dev/null || fail "$who en body is not a complete schema-1 catalog"

  s=$(get "$who-en304" /fomio/app-locales/1/en.json -H "If-None-Match: $etag" "$@")
  [ "$s" = 304 ] && pass "$who en conditional 304" || fail "$who en conditional status $s"
  [ -z "$(header "$who-en304" X-Discourse-Username)" ] && pass "$who 304 has no X-Discourse-Username" || fail "$who 304 names a member"

  for path in /fomio/app-locales/1/xx.json /fomio/app-locales/2/index.json /fomio/app-locales/1/AR.json; do
    s=$(get "$who-neg" "$path" "$@"); [ "$s" = 404 ] && pass "$who $path 404" || fail "$who $path status $s"
  done
}

check_catalogs anonymous
cp "$TMP/anonymous-en.b" "$TMP/anon-en.json"

if [ -n "${FOMIO_MEMBER_API_KEY:-}" ] && [ -n "${FOMIO_MEMBER_USERNAME:-}" ]; then
  check_catalogs member -H "User-Api-Key: $FOMIO_MEMBER_API_KEY"
  cmp -s "$TMP/anon-en.json" "$TMP/member-en.b" && pass "member en body identical to anonymous" || fail "member en body differs from anonymous"
  grep -q -F "$FOMIO_MEMBER_USERNAME" "$TMP/member-index.b" "$TMP/member-en.b" && fail "member username present in a body" || pass "member username absent from bodies"
else
  echo "SKIP  member checks (set FOMIO_MEMBER_API_KEY and FOMIO_MEMBER_USERNAME to run them)"
fi
exit $FAIL
