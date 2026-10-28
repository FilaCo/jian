#!/usr/bin/env bash
set -euo pipefail

# Compile consumers directly to keep intentionally invalid packages out of cjpm's source tree.
root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"
cjpm build
fixture_tmp=$(mktemp -d)
trap 'rm -rf "$fixture_tmp"' EXIT
for fixture in tests/compile_fail/*.cj; do
    expected=$(sed -n 's|^// expect-error: ||p' "$fixture")
    if [[ -z "$expected" ]]; then
        echo "Missing expected diagnostic: $fixture" >&2
        exit 1
    fi
    cp "$fixture" "$fixture_tmp/fixture.cj"
    if cjc "$fixture_tmp/fixture.cj" --import-path "$root/target/release/jian" \
        --output-type=staticlib -o "$fixture_tmp/libfixture.a" \
        > "$fixture_tmp/output" 2>&1; then
        echo "Expected compilation to fail: $fixture" >&2
        exit 1
    fi
    if ! grep -F -- "$expected" "$fixture_tmp/output" > /dev/null; then
        echo "Missing diagnostic '$expected': $fixture" >&2
        cat "$fixture_tmp/output" >&2
        exit 1
    fi
    echo "PASS $fixture"
done
