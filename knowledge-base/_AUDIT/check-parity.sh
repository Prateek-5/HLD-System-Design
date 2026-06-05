#!/usr/bin/env bash
# Knowledge-base parity check — catches the drift the audit found.
# Asserts: per-domain counts in INDEX match disk; every topic has a starter
# card; total topic count is consistent; and every internal .md link resolves.
# Usage:  bash _AUDIT/check-parity.sh   (run from the knowledge-base/ dir or anywhere)
set -uo pipefail

KB="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$KB"
fail=0

DOMAINS=(architecture-patterns caching concurrency database-internals distributed-systems js-runtime networking observability scalability system-failures)

echo "== 1. Per-domain topic counts vs INDEX.md =="
total=0
for d in "${DOMAINS[@]}"; do
  n=$(find "$d" -name '*.md' | wc -l | tr -d ' ')
  total=$((total + n))
  # Map dir -> INDEX heading label
  label=$(echo "$d" | sed -E 's/-/ /g' | awk '{for(i=1;i<=NF;i++)$i=toupper(substr($i,1,1)) substr($i,2)}1')
  # special-case capitalisation used in INDEX
  label=${label/Js Runtime/JavaScript Runtime}
  idx=$(grep -oE "### ${label} \(([0-9]+)\)" INDEX.md | grep -oE '[0-9]+' | head -1)
  if [ "$idx" != "$n" ]; then echo "  MISMATCH $d: disk=$n INDEX='$idx'"; fail=1; else echo "  ok  $d = $n"; fi
done
echo "  total topic files: $total"

echo "== 2. Starter cards == topic files =="
cards=$(grep -c '^### ' STARTER-CARDS.md)
if [ "$cards" -ne "$total" ]; then echo "  MISMATCH: STARTER-CARDS has $cards cards, expected $total"; fail=1; else echo "  ok  $cards cards == $total topics"; fi

echo "== 3. Internal .md links resolve (nav files) =="
broken=0
for f in *.md _AUDIT/*.md; do
  [ -f "$f" ] || continue
  grep -oE '\]\(([A-Za-z0-9._/-]+\.md)[^)]*\)' "$f" | sed -E 's/^\]\(//; s/[) ].*$//' | while read -r lnk; do
    case "$lnk" in /*) continue;; esac
    tgt="$(cd "$(dirname "$f")" && cd "$(dirname "$lnk")" 2>/dev/null && pwd)/$(basename "$lnk")"
    [ -f "$tgt" ] || echo "  BROKEN in $f -> $lnk"
  done
done
echo "  (no BROKEN lines above = all internal links resolve)"

echo
if [ "$fail" -eq 0 ]; then echo "PARITY OK"; else echo "PARITY FAILED"; exit 1; fi
