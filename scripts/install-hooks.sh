#!/usr/bin/env bash
#
# Install the identity-scan git hooks.
#
#   bash scripts/install-hooks.sh
#
# Git never clones hooks, so this has to be run once per clone. It is also
# safe to re-run — it just overwrites the hook files.
#
# Two hooks, deliberately:
#   pre-commit  scans staged files, so a mistake is caught before it is
#               recorded in history at all.
#   pre-push    scans every tracked file, which catches anything that reached
#               a commit some other way (a --no-verify, an edit made outside
#               this repo's tooling, a merge).

set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
HOOKS="$ROOT/.git/hooks"
mkdir -p "$HOOKS"

cat > "$HOOKS/pre-commit" <<'EOF'
#!/usr/bin/env bash
exec bash "$(git rev-parse --show-toplevel)/scripts/identity-scan.sh"
EOF

cat > "$HOOKS/pre-push" <<'EOF'
#!/usr/bin/env bash
exec bash "$(git rev-parse --show-toplevel)/scripts/identity-scan.sh" --all
EOF

chmod +x "$HOOKS/pre-commit" "$HOOKS/pre-push"

echo "Installed:"
echo "  .git/hooks/pre-commit   scans staged files"
echo "  .git/hooks/pre-push     scans all tracked files"
echo ""
echo "Test with:  bash scripts/identity-scan.sh --all"
