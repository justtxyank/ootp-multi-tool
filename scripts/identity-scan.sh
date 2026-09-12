#!/usr/bin/env bash
#
# identity-scan.sh — refuse to publish anything carrying the owner's real
# identity or a path on the owner's machine.
#
#   ./scripts/identity-scan.sh          scan STAGED files (what pre-commit runs)
#   ./scripts/identity-scan.sh --all    scan every tracked file
#   ./scripts/identity-scan.sh <paths>  scan specific files
#
# Exit 0 = clean. Exit 1 = something was found; the commit is blocked.
#
# This site is published under the handle "justtxyank" and nothing public may
# link it to a real identity. The rule from the owner is explicit: if a scan
# finds something, FLAG IT AND ASK — never quietly rewrite the file. A hit may
# be a false positive (see identity-allow.txt), and the owner decides.
#
# Binary files are scanned too, on purpose. Image metadata routinely carries
# the full path of the machine that produced it, which is the least obvious
# way a username reaches a public server.

set -uo pipefail

cd "$(git rev-parse --show-toplevel)" || exit 1

ALLOW="scripts/identity-allow.txt"

# Patterns that must never reach a published file. Case-insensitive.
# Keep these as fragments, not full paths — the point is to catch the username
# and the person, wherever they appear.
PATTERNS=(
  'jboul'                 # the Windows username; appears in every local path
  'boulet'                # surname
  '\bjustin\b'            # first name, as a whole word
  'C:\\Users'             # a Windows path on this machine
  'C:/Users'              # ...the forward-slash form
  'OneDrive'
  'Dropbox'
  '[A-Za-z0-9._%+-]+@gmail\.com'
  'protonmail'            # retired from the site in favour of feedback@; see notes
)

# Which files to look at.
if [ "${1:-}" = "--all" ]; then
  mapfile -t FILES < <(git ls-files)
elif [ $# -gt 0 ]; then
  FILES=("$@")
else
  mapfile -t FILES < <(git diff --cached --name-only --diff-filter=ACMR)
fi

# Nothing staged is not a failure.
if [ ${#FILES[@]} -eq 0 ]; then
  echo "identity-scan: nothing to scan."
  exit 0
fi

# An allowlist entry is a literal line of text known to be safe. Matching on
# the whole line keeps it tight: allowing one comment does not allow the same
# word somewhere it actually matters.
allowed() {
  [ -f "$ALLOW" ] || return 1
  local line="$1"
  grep -Fqx -- "$line" "$ALLOW" 2>/dev/null
}

hits=0
report=""

for f in "${FILES[@]}"; do
  [ -f "$f" ] || continue
  [ "$f" = "$ALLOW" ] && continue          # the allowlist quotes the words it allows
  [ "$f" = "scripts/identity-scan.sh" ] && continue   # so does this file

  for pat in "${PATTERNS[@]}"; do
    # -a: treat binaries as text, so image metadata is searched too.
    while IFS= read -r match; do
      [ -z "$match" ] && continue
      lineno="${match%%:*}"
      text="${match#*:}"
      allowed "$text" && continue
      # Trim for display; a minified line could be enormous.
      short=$(printf '%s' "$text" | cut -c1-120)
      report+="  $f:$lineno"$'\n'"    $short"$'\n'
      hits=$((hits + 1))
    done < <(grep -a -n -i -E -- "$pat" "$f" 2>/dev/null)
  done
done

if [ "$hits" -eq 0 ]; then
  echo "identity-scan: clean (${#FILES[@]} file(s))."
  exit 0
fi

echo ""
echo "================================================================"
echo " IDENTITY SCAN FAILED — $hits match(es). Commit blocked."
echo "================================================================"
echo ""
printf '%s' "$report"
echo ""
echo "This site is published as \"justtxyank\". Nothing public may carry a real"
echo "name, a personal email, or a path on this machine."
echo ""
echo "DO NOT auto-strip these. Look at each one and decide:"
echo ""
echo "  - Genuinely sensitive?  Remove it, then commit again."
echo "  - A false positive?     Add the exact line to $ALLOW,"
echo "                          with a comment saying why it is safe."
echo ""
echo "If an image is flagged, the hit is probably metadata, not pixels."
echo "Re-encoding the image strips it (see assets/img/README.txt)."
echo ""
exit 1
