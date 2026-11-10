#!/usr/bin/env bash
# Nasazení: push zdrojů do webhunter-navrhy/<slug> (main) -> GitHub Action sestaví a nasadí Pages.
# Stejnou cestou ukládá administrace /admin/ (webhunter-admin commitne _data/*.json a img/uploads/…).
#   ./deploy.sh            # build lokálně (kontrola), commit, push, počkat na Action, ověřit version.json, QA
#   ./deploy.sh --bez-qa
# NIKDY nenastavovat vlastní doménu ani CNAME (10. 11. 2026 tservice.sk přesměrovávala náhled na rozbitý starý web).
set -euo pipefail
cd "$(dirname "$0")"
QA=1; for a in "$@"; do [ "$a" = "--bez-qa" ] && QA=0; done
PY="${PY:-/Library/Frameworks/Python.framework/Versions/3.14/bin/python3}"
export SSL_CERT_FILE="$($PY -c 'import certifi;print(certifi.where())')"
SLUG="$($PY -c 'import json;print(json.load(open("_data/site.json"))["slug"])')"
URL="$($PY -c 'import json;print(json.load(open("_data/site.json"))["url"])')"
REPO="webhunter-navrhy/$SLUG"
TOKEN="$(cat ~/.webhunter-gh-token)"; export GH_TOKEN="$TOKEN"
PUSH_URL="https://x-access-token:${TOKEN}@github.com/$REPO.git"
export PATH="/opt/homebrew/bin:$PATH"

echo "== build (lokální kontrola)"; "$PY" build.py
echo "== commit + push"
git pull -q --rebase "$PUSH_URL" main 2>/dev/null || true
git add -A
git -c user.name="WebHunter" -c user.email="info@webhunter.cz" commit -q -m "Aktualizace webu $(date +%F\ %H:%M)" || echo "(nic nového)"
git push -q "$PUSH_URL" HEAD:main
SHA="$(git rev-parse HEAD)"
echo "== Pages přes Actions"
gh api "repos/$REPO/pages" --jq .build_type 2>/dev/null | grep -q workflow || gh api -X PUT "repos/$REPO/pages" -f build_type=workflow >/dev/null
echo "== čekám na nasazení $SHA"
V=""
for i in $(seq 1 60); do
  V="$(curl -sL "${URL}version.json?t=$(date +%s)" | $PY -c 'import json,sys;print(json.load(sys.stdin).get("sha",""))' 2>/dev/null || true)"
  [ "$V" = "$SHA" ] && { echo "  nasazeno"; break; }
  if [ "$i" = 30 ]; then gh run list -R "$REPO" -L 1 || true; fi
  sleep 8
done
[ "$V" = "$SHA" ] || { echo "CHYBA: web neukazuje nový commit"; gh run list -R "$REPO" -L 3; exit 3; }
if [ "$QA" = 1 ]; then "$PY" ~/wh-navrhy-ops/tools/qa.py "$URL" "$PWD/qa" || { echo "QA našlo chyby (qa/qa.json)"; exit 1; }; fi
echo "HOTOVO: $URL"
