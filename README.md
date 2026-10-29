# jian

A Typer-like CLI framework for Cangjie. Write a function; `@JianCommand` reads
its declaration at compile time and generates the argument parsing. Values reach
the function with their declared types, without type erasure or runtime casts.

## Install

jian currently targets Cangjie 1.3.0 alpha nightlies. The examples are checked
with `cjc 1.3.0-alpha.20261014001050`; older SDKs may not support the macro API.
Load your SDK environment before running `cjpm`.

Create an application:

```bash
cjpm init --type=executable --path demo --name demo
```

Add a git dependency to `demo/cjpm.toml`:

```toml
[dependencies]
jian = { git = "https://github.com/FilaCo/jian.git", branch = "master" }
```

Only one import is needed: `import jian.*` includes the macros and runtime API.
See [Development](docs/development.md) for toolchain setup and checks.

## First command

Put this in `demo/src/main.cj` (also available as
[the greet example](examples/greet/src/main.cj)):

```cangjie
package demo

import jian.*

@JianCommand[help: "Greet someone."]
func greet(
    name!: String = JianArgument(help: "Name to greet"),
    times!: Int64 = JianOption(short: 't', help: "Repetitions", default: 1),
    loud!: Bool = JianOption(short: 'l', help: "Use uppercase", default: false)
): Unit {
    let message = "Hello, ${name}!"
    for (_ in 0..times) {
        println(if (loud) { message.toAsciiUpper() } else { message })
    }
}

let app = JianApp(name: "demo", help: "A first jian CLI.").add(greet)

main(args: Array<String>): Int64 { app.run(args) }
```

Run from the `demo` directory:

```bash
cjpm run -- greet Alice
# Hello, Alice!
cjpm run -- greet Alice -lt2
# HELLO, ALICE!
# HELLO, ALICE!
cjpm run -- --help
cjpm run -- greet --help
```

The macro preserves the function `greet`; `.add(greet)` registers its CLI adapter.
Call `greet(name: "Alice", times: 2)` directly without CLI parsing. The function
keeps the declared parameter types and defaults. The command name is `greet`;
camelCase and snake_case CLI names become kebab-case. `JianApp` needs no context;
`JianContextApp<C>` receives typed dependencies. `app.run` takes arguments
excluding the executable name, which is exactly what `main(args)` receives.

## Parameters become arguments and options

Without a marker, positional function parameters become CLI arguments and
named parameters (`!`) become options. Markers add help, a short alias or an
explicit CLI kind.

| Function parameter | CLI behavior |
| --- | --- |
| `name: String` | Required argument `NAME` |
| `times!: Int64 = 1` | Option `--times <INT>`, default `1` |
| `loud!: Bool = false` | Flag `--loud`, default `false` |
| `jobs!: ?Int64` | Optional `--jobs <INT>`, absent → `None` |
| `tags!: Array<String> = []` | Repeated option `--tags a --tags b` |
| `files: Array<Path>` as the last positional parameter | Required variadic argument |
| `name!: String = JianArgument(help: "Name")` | Required CLI argument, named in direct calls |
| `times!: Int64 = JianOption(short: 't', default: 1)` | `--times` with alias `-t` |

An input without a default is required unless its type permits absence:
standard `?T` does, while `Bool` and `Array<T>` require an occurrence. Supply
`false` or `[]` explicitly when they may be omitted. Defaults are evaluated only
when needed and may refer to earlier parameters or private names.

Standard value types include `String`, integer and float types, `Bool`,
`std.fs.Path`, `Option<T>` and `Array<T>`. Paths are parsed without checking
whether they exist. Repeating a scalar option replaces its value; repeating an
array option appends an element.

Options accept `--times=2`, `--times 2`, `-t2`, `-t=2` and `-t 2`. Short flags
can be clustered (`-lt2`). `--` ends option recognition, so `greet -- -h` greets
the name `-h`. A value-taking option consumes the next token even when it looks
like another option.

Both markers support `help`, `hidden` and `default`; `JianOption` also supports
one ASCII short name. `-h` and `--help` are reserved. Hidden inputs remain
accepted but are omitted from help. Cangjie requires `!` on parameters with
defaults, including `JianArgument(...)`; their CLI kind is independent of direct
function-call naming. See [Arguments and options](docs/arguments-and-options.md)
for optional aliases, direct calls and marker constraints.

## Apps, sub-apps and callbacks

Create an app before registering its commands and callback. Mount an app with an
explicit name; the name belongs to this connection, so one app can appear under
several names:

```cangjie
let users = JianApp(help: "User management.")

@JianCommand[users]
func create(name: String): Unit {
    println("Creating ${name}")
}

let app = JianApp(name: "demo")
    .add(users, name: "users")
    .add(users, name: "admins", help: "Administrator management.")

@JianCallback[app]
func configure(verbose!: Bool = false): JianCallbackResult {
    if (verbose) { println("Verbose mode enabled") }
    JianCallbackResult.Continue
}
```

Run `demo users create Alice` or `demo admins create Alice`. Both mounts share the
same child app. The optional mount `help` overrides its description only on that
path, including that group's help. A standalone app defaults to the usage name
`app` if `name` is omitted. Duplicate command/group names, duplicate callbacks
and mount cycles throw `IllegalArgumentException` during assembly.

Commands can live in any file of the same package. A package can export just its
`public let app`; importing it includes that package's command registrations.
Registering into an imported app from another package also works, but that
additional package must itself be imported by the executable's dependency graph.
There is no package discovery. See [Applications and composition](docs/applications.md)
for package layouts and initialization rules.

The [sub-app example](examples/sub_apps/src/main.cj) combines a `--verbose` / `-v`
callback with a nested `project` app:

```bash
cd examples/sub_apps
cjpm run -- -v project deploy staging
# Verbose mode enabled
# Deploy to staging
cjpm run -- project --help
cjpm run -- project deploy --help
```

App options go before the subcommand; options after it belong to that command
or sub-app. Callbacks return `JianCallbackResult`: `Continue` proceeds to the
selected command, while `Exit(code)` returns immediately from `app.run`, including
`Exit(0)`. The return type may be inferred. A callback-only app may run without
a subcommand. See [callback completion](docs/applications.md#callback-completion)
for options such as `--config-schema` that complete without a subcommand.

For a default action, inject `invocation!: JianInvocation = JianCurrentInvocation()`
into the callback. After parsing its own arguments and options,
`invocation.requestedSubcommand` is `None` when no command was requested; call an
ordinary function for the default action and return `Exit(code)`. Known and unknown
names both produce `Some(name)`, so typos retain their normal errors after
`Continue`. This works in both app types, independently of typed dependencies.
Describe the default action with the callback's `help:` setting; usage retains
`COMMAND [ARGS]...` for apps with registered commands or groups.
Direct calls supply `JianInvocation` explicitly. See
[invocation metadata and default actions](docs/applications.md#invocation-metadata-and-default-actions).

## Typed context

Use `@JianContext` on an application state class and request its fields with
`JianFromContext<C>()`. The parameter's declared type selects the field; requesting
`C` itself supplies the whole context. Injected dependencies never become CLI
arguments or options and do not need `JianArgValue`.

```cangjie
@JianContext
class AppContext {
    public let logger: Logger = Logger()
}

let app = JianContextApp<AppContext>(name: "demo")

@JianCallback[app]
func configure(ctx!: AppContext = JianFromContext<AppContext>(), verbose!: Bool = false): JianCallbackResult {
    ctx.logger.verbose = verbose
    JianCallbackResult.Continue
}

@JianCommand[app]
func greet(name: String, logger!: Logger = JianFromContext<AppContext>()): Unit {
    logger.greet(name)
}

// Create the context outside commands and callbacks; supply it on every run.
let context = AppContext()
app.run(["--verbose", "greet", "Alice"], context: context)
```

Here `Logger` is an application-defined class. The runnable
[context example](examples/context/src/main.cj) includes its implementation and
extracts a child context for commands in a separate package. See
[Typed context](docs/context.md) for lifetime, type restrictions and direct calls.

## Custom value types

Implement `JianArgValue<T>` on your type to define its CLI behavior:

| Static member | Contract |
| --- | --- |
| `takesValue(): Bool` | Whether an occurrence consumes text; `false` for flags |
| `metavar(): String` | Help placeholder, such as `COLOR` |
| `accept(prev: ?T, raw: ?String): T` | Parse an occurrence; `prev` is the accumulated value and `raw = None` is a bare flag |
| `whenAbsent(): ?T` | Fallback when absent; outer `None` means required |

Throw `JianInvalidValueException(raw, expected)` for invalid text. The generated
parser adds the argument or option name to the error. Throw `JianUsageException`
for other usage failures.

The [custom type example](examples/custom_type/src/main.cj) implements this
interface on a `Color` enum that accepts `red` or `blue`. The command receives a
`Color` directly; the same implementation also supports `?Color` and
`Array<Color>` through the library's generic extensions.

```bash
cd examples/custom_type
cjpm run -- paint --color blue
# Painting blue
cjpm run -- paint --color green
# Error: invalid value 'green' for '--color': expected red or blue
# ... usage, exit code 2
```

## Help, errors and exit codes

`--help` and `-h` work for apps, commands and nested apps. Help uses generated
metadata, includes declared defaults and lists commands alphabetically. It
returns `0` without invoking the target; ancestor callbacks still run before
help for a nested target.

| Result | Behavior |
| --- | --- |
| Command returns `Unit` | Exit code `0` |
| Command returns `Int64` | Use that code |
| Callback returns `JianCallbackResult.Continue` | Continue dispatch |
| Callback returns `JianCallbackResult.Exit(code)` | Return that code immediately |
| Help requested | Print help to stdout, return `0` |
| `JianUsageException` | Print error and usage to stderr, return `2` |
| Other exception | Propagate to the caller |

Return `app.run(args)` from `main` to preserve these codes for an app without
context. Apps with context use `app.run(args, context: ctx)`. The library never calls
`exit()`. Both app types accept `stdout` and `stderr` streams for testing.

## Examples and checks

Each example is a standalone executable with a path dependency on this checkout.
Run it from its directory with `cjpm run -- ...`.

| Example | Demonstrates | Arguments |
| --- | --- | --- |
| [callback_exit](examples/callback_exit/src/main.cj) | Default action, callback completion and subcommands | no arguments, `--config-schema` or `fetch-src` |
| [greet](examples/greet/src/main.cj) | Arguments, defaults, flags and short clusters | `greet Alice -lt2` |
| [sync](examples/sync/src/main.cj) | Variadic paths, repeated options, optional values | `sync src docs -nj4 -x target --exclude=.git` |
| [sub_apps](examples/sub_apps/src/main.cj) | Callback and nested app | `-v project deploy staging` |
| [custom_type](examples/custom_type/src/main.cj) | User-defined enum parsing | `paint --color blue` |
| [context](examples/context/src/main.cj) | Typed dependencies, callback configuration and nested app | `--verbose people greet Alice` |

The sync and deploy examples only print plans; they do not modify files or deploy.
Run the complete check suite from the repository root:

```bash
bash tests/check.sh
```

This runs unit tests, compile-fail diagnostics and builds and exercises every
example. The repository's `pre-push` hook runs the same suite.

## Current limits

- No environment-variable defaults or automatic enum parsers. Enums can implement
  `JianArgValue<T>` explicitly.
- Help is explicit (`help:`); doc comments are not extracted.
- Generic command and callback functions are rejected. Commands return `Unit` or
  `Int64`; callbacks return `JianCallbackResult`. Return types may be inferred.
- A variadic argument must be the final positional argument. Only one overload of
  a given function name can carry each command or callback macro, because generated
  adapter names come from the function name.
- Optional type aliases keep their CLI behavior, but need an explicit `None`
  default to make named parameters omissible in direct function calls.
