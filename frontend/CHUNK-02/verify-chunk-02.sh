#!/usr/bin/env bash
# NEWS CHUNK 2 — Frontend Base UI Layout
# Author: GPT-5 Codecs (acting as a 30–40 year experienced software engineer)
# Behavior: Full write access. Create files, run checks, save results.

# Delegate to the shared scripts directory so the verification logic stays in one place.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
"${PROJECT_ROOT}/../scripts/verify-chunk-02.sh" "$@"
