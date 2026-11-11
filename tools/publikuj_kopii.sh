#!/usr/bin/env bash
# Sestaví web pro jednu doménu (WH_DOMENA) a nasadí ho do kopie repa (main, kořen = GitHub Pages z větve).
#   tools/publikuj_kopii.sh <domena> <owner/repo> [větev=main]      (potřebuje GH_TOKEN s právem zápisu do kopie)
set -euo pipefail
DOM="$1"; REPO="$2"; BR="${3:-main}"
cd "$(dirname "$0")/.."
WH_DOMENA="$DOM" python build.py
TMP="$(mktemp -d)"
cp -R dist/. "$TMP/"
cd "$TMP"
git init -q -b "$BR"
git add -A
git -c user.name="WebHunter" -c user.email="info@webhunter.cz" commit -q -m "Nasazení ${GITHUB_SHA:-local} pro $DOM"
git push -q --force "https://x-access-token:${GH_TOKEN}@github.com/${REPO}.git" "$BR"
echo "OK: $DOM -> $REPO"
