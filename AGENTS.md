# jian

A Typer-like CLI framework for Cangjie: a command is a plain function, and the `@Command`/`@Callback` macros read its declaration at compile time to generate the argument parsing for it.

## Goals

- **No type erasure.** A parameter's type comes from the function's declaration and reaches the function unchanged; no `Any`, no runtime casts, no string-keyed lookups the compiler cannot check. A mistake in a CLI declaration is a compile error, not a runtime one.
- **Ergonomics first.** The user-facing API is the function, its parameters and their defaults; whatever the macros generate is an implementation detail, not something users are expected to write by hand.

## Build & test

From the repo root (in Claude Code sessions `cjpm` is on `PATH` through the `SessionStart` hook in `.claude/settings.json`; in a shell of your own, `source ~/.cangjie/envsetup.sh` once):

- `cjpm build` · `cjpm build -l` (with cjlint). `-l` fails here with `MANDATORY ... violated` and `Exception caught: Dereferencing a null pointer`: cjlint (1.3.0-alpha.20261014) crashes, most runs, on a package of this module that calls a macro of the *root* macro package (`src/tests`). A non-root macro package does not trigger it, nor does a module depending on jian. Until cjlint is fixed, lint with the macro-using packages moved out of `src/`.
- `cjpm test --target-dir target/test` — all tests. `cjpm build` and `cjpm test` in one target dir undo each other's incremental cache.
- A subset: `cjpm test --target-dir target/test src/runtime`, or `'--filter=LexerTest.*'` (quote it: fish).

`cjpm` leaves `*.cj.macrocall` and `lib-macro_*.dylib` next to the sources: untracked build output.

The library is `output-type = "static"`: across a shared-library boundary cjc can drop extension funcTables and the process aborts at run time.

## Macros

`@Command` and `@Callback` live in the root package, a `macro package jian` (`src/*.cj`), which may export macros only — runtime API the generated code calls lives in `jian.runtime` (`src/runtime`), and the root `public import`s it so users write a single `import jian.*`. Generated code is `quote(...)` naming things unqualified, so it resolves in the *user's* package: everything it refers to must be public and imported there. A green build of the macro package proves nothing about its output; a build of a package using the macro does — test macros that way, in `jian.tests` (`src/tests`).

Each macro is declared twice, attributed (`@Command[help: ...]`) and plain (`@Command`): cjc rejects the plain form of a macro declared only with `attrs`.

## Tests

Unit tests sit beside the code as `*_test.cj` in the same package (`std.unittest`: `@Test`/`@TestCase`, `@Expect`/`@Assert`), cases in `// arrange` / `// act` / `// assert`, named as sentences. Library code never calls `exit()`: it returns or throws, so that dispatch can be tested.

## Commits

Conventional Commits, checked by commitlint on `commit-msg` (husky); run `npm install` once per clone to activate the hook. PRs into `master`.
