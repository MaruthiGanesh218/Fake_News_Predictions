#!/usr/bin/env bash
# Wrapper delegating to repo-level connectivity check script
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
exec "${ROOT_DIR}/scripts/verify-connection.sh" "$@"
