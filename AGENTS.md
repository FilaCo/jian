# jian

A Typer-like CLI framework for Cangjie: a command is a plain function, and the `@JianCommand`/`@JianCallback` macros read its declaration at compile time to generate the argument parsing for it.

## Goals

- **No type erasure.** A parameter's type comes from the function's declaration and reaches the function unchanged; no `Any`, no runtime casts, no string-keyed lookups the compiler cannot check. A mistake in a CLI declaration is a compile error, not a runtime one.
- **Ergonomics first.** The user-facing API is the function, its parameters and their defaults; whatever the macros generate is an implementation detail, not something users are expected to write by hand.

## Build & test

Run commands from the repository root. Setup, SDK selection, Git hooks
and troubleshooting are in [Development](docs/development.md). Codex reads this
file as repository guidance; load the SDK environment in the shell running a
command if `cjpm` is not already available.

- `cjpm build` — build the library.
- `cjpm test --target-dir target/test` — all tests. `cjpm build` and `cjpm test` in one target dir undo each other's incremental cache.
- A subset: `cjpm test --target-dir target/test src/runtime`, or `'--filter=ArgCursorTest.*'` (quote it: fish).

`cjpm` leaves `*.cj.macrocall` and `lib-macro_*.dylib` next to the sources: untracked build output.

## Public API naming

Framework-owned public types and macros use the `Jian` prefix, including
`JianOption` and `JianArgument`. Public free functions use a `jian` prefix in
camelCase, such as `jianAcceptAs`. Members retain their ordinary names.
Generated adapter names come from the user's function (`GreetCommand`,
`ConfigureCallback`); they do not add the framework prefix.

## Macros

`@JianCommand` and `@JianCallback` live in the root package, a `macro package jian` (`src/*.cj`), which may export macros only — runtime API the generated code calls lives in `jian.runtime` (`src/runtime`), and the root `public import`s it so users write a single `import jian.*`. Generated code is `quote(...)` naming things unqualified, so it resolves in the *user's* package: everything it refers to must be public and imported there. A green build of the macro package proves nothing about its output; a build of a package using the macro does — test macros that way.

Each macro is declared twice, attributed (`@JianCommand[help: ...]`) and plain (`@JianCommand`): cjc rejects the plain form of a macro declared only with `attrs`.

Short option names are single ASCII bytes: `JianParamSpec.short` is `?Byte`,
`JianArg.Short` carries one `Byte`, and `JianArgCursor` takes `Array<Byte>` for shorts
requiring values. The cursor splits short clusters. `JianOption(short: 'v')`
rejects non-ASCII short names at compile time; `-h` is reserved for help.

`JianOption(...)` and `JianArgument(...)` are parameter-default markers, rewritten by
`@JianCommand` and `@JianCallback`. Cangjie requires `!` on parameters with defaults,
including `path!: String = JianArgument(...)`; the marker makes it positional in
the CLI while direct function calls remain named. Keep function-call naming
separate from CLI parameter kind. Without a marker, `!` determines CLI kind.
Without an explicit default, only optional standard types (`?T`) allow absence;
Bool and Array require an occurrence or an explicit default. See
[Parameter declarations](docs/parameters.md).

## Tests

Unit tests sit beside the code as `*_test.cj` in the same package (`std.unittest`: `@Test`/`@TestCase`, `@Expect`/`@Assert`), cases in `// arrange` / `// act` / `// assert`, named as readable camelCase sentences. Library code never calls `exit()`: it returns or throws, so that dispatch can be tested.

## Commits

Conventional Commits, checked by `cog` through `.githooks/commit-msg` and in CI
(commits and PR titles). Activate hooks with `git config core.hooksPath .githooks`.
PRs into `master`.
