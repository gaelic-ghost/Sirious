#!/usr/bin/env sh
set -eu

SELF_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
export REPO_MAINTENANCE_COMMON_DIR="$SELF_DIR/lib"
. "$SELF_DIR/lib/common.sh"

sample_hook="$REPO_MAINTENANCE_ROOT/hooks/pre-commit.sample"
installed_hook="$REPO_ROOT/.git/hooks/pre-commit"

[ -f "$sample_hook" ] || die "SwiftFormat hook installation expected $sample_hook to exist."
[ -d "$REPO_ROOT/.git/hooks" ] || die "SwiftFormat hook installation expected $REPO_ROOT/.git/hooks to exist. Run this inside the Sirious Git checkout."

cp "$sample_hook" "$installed_hook"
chmod +x "$installed_hook"

log "Installed SwiftFormat pre-commit hook at $installed_hook."
