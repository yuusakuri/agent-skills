#!/usr/bin/env bash
set -euo pipefail

TEST_DIRECTORY="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"${PYTHON_BIN:-python3}" "${TEST_DIRECTORY}/source_patch_test.py"
