#!/usr/bin/env bash
set -euo pipefail

echo "Post-commit: updating Claude Code and plugins..."

git push

claude update

claude plugin marketplace list --json | jq -r '.[].name' | xargs -L 1 -I{} claude plugin marketplace update {}

make install
