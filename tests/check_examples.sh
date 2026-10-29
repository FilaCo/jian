#!/usr/bin/env bash
set -euo pipefail

root=$(cd "$(dirname "$0")/.." && pwd)
for manifest in "$root"/examples/*/cjpm.toml; do
    (cd "$(dirname "$manifest")" && cjpm build)
done

example_tmp=$(mktemp -d)
trap 'rm -rf "$example_tmp"' EXIT

check() {
    local example=$1 expected_code=$2 expected_output=$3 expected_error=$4
    shift 4
    local code=0
    "$root/examples/$example/target/release/bin/main" "$@" \
        > "$example_tmp/stdout" 2> "$example_tmp/stderr" || code=$?
    if [[ $code != "$expected_code" ]] ||
        [[ $(cat "$example_tmp/stdout") != "$expected_output" ]] ||
        [[ $(cat "$example_tmp/stderr") != "$expected_error" ]]; then
        echo "FAIL $example $* (exit $code; expected $expected_code)" >&2
        cat "$example_tmp/stdout" "$example_tmp/stderr" >&2
        exit 1
    fi
    echo "PASS $example $*"
}

check greet 0 'Hello, Alice!' '' greet Alice
check greet 0 $'HELLO, ALICE!\nHELLO, ALICE!' '' greet Alice -lt2
check greet 0 'Hello, -h!' '' greet -- -h
check sync 0 $'jobs=4, dry-run=true\npath=src\npath=docs\nexclude=target\nexclude=.git' '' \
    sync src docs -nj4 -x target --exclude=.git
check sync 0 $'jobs=1, dry-run=false\npath=src' '' sync src
check sub_apps 0 $'Verbose mode enabled\nDeploy to staging' '' -v project deploy staging
check sub_apps 0 'Deploy to production' '' deploy production
check custom_type 0 'Painting blue' '' paint --color blue
check custom_type 2 '' $'Error: invalid value \'green\' for \'--color\': expected red or blue\nUsage: demo paint [OPTIONS]' \
    paint --color green
check context 0 $'Greeting Alice\nHello, Alice!' '' --verbose people greet Alice
check context 0 'Hello, Alice!' '' people greet Alice
check callback_exit 0 '{"type":"object"}' '' --config-schema
check callback_exit 0 '{"type":"object"}' '' --config-schema fetch-src
check callback_exit 0 'Fetching source files' '' fetch-src
check callback_exit 2 '' $'Error: missing argument \'COMMAND\'\nUsage: demo [OPTIONS] COMMAND [ARGS]...'
check callback_exit 2 '' $'Error: unknown command \'fetch-scr\'\nUsage: demo [OPTIONS] COMMAND [ARGS]...' fetch-scr

for manifest in "$root"/examples/*/cjpm.toml; do
    example_dir=$(dirname "$manifest")
    "$example_dir/target/release/bin/main" --help > "$example_tmp/help"
    grep -F 'Usage: demo' "$example_tmp/help" > /dev/null
done
