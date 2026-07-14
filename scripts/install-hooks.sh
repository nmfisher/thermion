#!/usr/bin/env bash
# One-time hook install. Run from any directory; resolves repo root via git.
set -e

repo_root=$(git rev-parse --show-toplevel)
hook_src="$repo_root/scripts/pre-commit"
hook_dst="$repo_root/.git/hooks/pre-commit"

chmod +x "$hook_src"
ln -sf ../../scripts/pre-commit "$hook_dst"

echo "Installed pre-commit hook: $hook_dst -> scripts/pre-commit"
