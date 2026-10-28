# Development

Run commands from the repository root. Shell examples use Bash;
start `bash` first if your interactive shell is fish. Quote test filters.

## Setup

Install a Cangjie SDK (nightly) and [cocogitto](https://docs.cocogitto.io/) (`cog`).
GitHub tasks use `gh`.

If using an SDK manager, select the SDK there. For a direct SDK installation,
load its environment in each shell that needs it, for example:

```bash
source ~/.cangjie/envsetup.sh
cjc --version
cjpm --version
cog --version
git config core.hooksPath .githooks
```

The hook setting replaces the former Husky path in an existing checkout. Node,
npm and commitlint are no longer needed. Git hooks use their caller's environment,
so the SDK and `cog` must also be available to the process running Git.

## Build and test

Run the complete suite (also used by the `pre-push` hook):

```bash
bash tests/check.sh
```

It runs unit tests, failing-consumer diagnostics and standalone example checks.
For individual checks:

```bash
cjpm build
cjpm test --target-dir target/test
cjpm test --target-dir target/test src/runtime
cjpm test --target-dir target/test '--filter=ArgCursorTest.*'
bash tests/check_compile_fail.sh
bash tests/check_examples.sh
```

Each `examples/*` directory is a standalone executable with a path dependency
on the repository root. The example check builds every manifest and checks CLI
output and exit codes, including an invalid custom value. To try one manually:

```bash
cd examples/greet
cjpm run -- greet Alice -lt2
```

Builds and tests use separate target directories because sharing one invalidates
their incremental caches. Do not run two writers against the same target
directory. If cjpm fails while deserializing an
old cache (`DataModelException: Expected DataModelSeq`), try a fresh directory,
such as `cjpm build --target-dir target/build-fresh`.

`*.cj.macrocall` and `lib-macro_*` beside sources are generated output.

### Macro consumers

Build a package that imports `jian.*` and uses the changed macro. Building the
macro package alone cannot validate its expansion, unqualified generated names
or the runtime re-export. Check that a hand-written `JianCommand` can implement the
runtime contract from a consumer package as well.

`bash tests/check_compile_fail.sh` builds the library, then compiles each
`tests/compile_fail/*.cj` consumer separately. A fixture must fail and include
its `// expect-error:` message. Keep invalid declarations in these fixtures,
so ordinary `cjpm test` can still compile and run all valid consumer tests.

## Commits and reviews

Use Conventional Commits (`type(scope): subject`); breaking changes use `!` or a
`BREAKING CHANGE:` footer. Target `master`. `.githooks/commit-msg` calls
`cog verify`; `.githooks/pre-push` checks whitespace and runs the complete suite.
Run any macro consumer checks appropriate to the change before review.
The GitHub workflow checks the PR's commits and title, including title edits.

```bash
cog verify 'feat: parse short option clusters'
cog check origin/master..HEAD
```

`cog.toml` configures version tags, changelog links and updating the manifest's
version for an explicitly requested bump. Release publishing is separate.

Argument and option syntax and default behavior are described in
[Arguments and options](arguments-and-options.md).
