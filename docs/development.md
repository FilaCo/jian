# Development

Run commands from the repository or worktree root. Shell examples use Bash;
start `bash` first if your interactive shell is fish. Quote test filters.

## Setup

Install a Cangjie SDK and [cocogitto](https://docs.cocogitto.io/) (`cog`). GitHub
tasks use `gh`. The layout in PR #20 was checked with
`cjc 1.3.0-alpha.20261014001050` on Linux x86_64; `cjc-version = "1.3.0"` in
`cjpm.toml` does not pin that exact nightly.

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

```bash
cjpm build
cjpm build -l
cjpm test --target-dir target/test
cjpm test --target-dir target/test src/runtime
cjpm test --target-dir target/test '--filter=LexerTest.*'
```

Builds and tests use separate target directories because sharing one invalidates
their incremental caches. Each worktree needs its own caches; do not run two
writers against the same target directory. If cjpm fails while deserializing an
old cache (`DataModelException: Expected DataModelSeq`), try a fresh directory,
such as `cjpm build --target-dir target/build-fresh`.

Libraries use static output: across shared-library boundaries, cjc can lose
extension funcTables and abort at runtime. Preserve `output-type = "static"`.
`*.cj.macrocall` and `lib-macro_*` beside sources are generated output.

### Macro consumers and lint

Build a package that imports `jian.*` and uses the changed macro. Building the
macro package alone cannot validate its expansion, unqualified generated names
or the runtime re-export. Check that a hand-written `Command` can implement the
runtime contract from a consumer package as well.

With SDK 1.3.0-alpha.20261014, the earlier `src/tests` consumer triggered
intermittent cjlint null-pointer crashes and `MANDATORY ... violated` reports.
The current tree, without that consumer, passes `cjpm build -l` with warnings.
The PR's probes found that a separate module depending on jian did not trigger
the crash. Prefer an external consumer fixture if the crash returns; preserve
consumer coverage and report the limitation. Do not move source directories out
of a live checkout to run lint.

## Commits and reviews

Use Conventional Commits (`type(scope): subject`); breaking changes use `!` or a
`BREAKING CHANGE:` footer. Target `master`. `.githooks/commit-msg` calls
`cog verify`; `.githooks/pre-push` checks whitespace, builds and runs unit tests.
Run lint and any macro consumer checks appropriate to the change before review.
The GitHub workflow checks the PR's commits and title, including title edits.

```bash
cog verify 'feat: parse short option clusters'
cog check origin/master..HEAD
```

Follow [issue #9](https://github.com/FilaCo/jian/issues/9) and its latest tracking
comment for the implementation order. Each child issue defines one PR and its
acceptance criteria. Update affected documentation with the code, and report
which checks ran and any remaining compiler limitations.

`cog.toml` configures version tags, changelog links and updating the manifest's
version for an explicitly requested bump. Release publishing is separate.

## Codex and worktrees

Codex's repository instructions live in [AGENTS.md](../AGENTS.md), following the
[official workflow guidance](https://developers.openai.com/cookbook/examples/codex/iterating-development-workflows-with-codex).
Human and
agent commands share this guide. The SDK environment comes from the shell or
SDK manager; no Claude SessionStart hook is required.

Use an independent worktree for concurrent tasks. Before removing a worktree,
check its tracked and untracked work and whether a process or another session
still uses it. An old index timestamp does not establish that it is idle.
