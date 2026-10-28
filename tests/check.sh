#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."
cjpm test --target-dir target/test
bash tests/check_compile_fail.sh
bash tests/check_examples.sh
