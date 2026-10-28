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

main(args: Array<String>): Int64 {
    JianApp(name: "demo", help: "A first jian CLI.")
        .add(GreetCommand())
        .run(args)
}
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

The macro preserves `greet` as a callable function and generates `GreetCommand()`
for registration. The command name is `greet`; camelCase and snake_case CLI names
become kebab-case. Registration is explicit. `JianApp.run` takes arguments
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

Register generated command adapters with `.add(GreetCommand())`. Register a
nested `JianApp` the same way. A function marked `@JianCallback` generates a
`ConfigureCallback` adapter from `configure`; set it with
`.callback(ConfigureCallback())` to parse app-level arguments and options before
dispatching to a command.

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
or sub-app. Callbacks run before the selected command. A nonzero callback exit
code stops dispatch. A callback-only app may run without a subcommand.

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
| Command or callback returns `Unit` | Exit code `0` |
| Command or callback returns `Int64` | Use that code |
| Help requested | Print help to stdout, return `0` |
| `JianUsageException` | Print error and usage to stderr, return `2` |
| Other exception | Propagate to the caller |

Return `JianApp.run(args)` from `main` to preserve these codes. The library never
calls `exit()`. `JianApp` accepts `stdout` and `stderr` streams for testing.

## Examples and checks

Each example is a standalone executable with a path dependency on this checkout.
Run it from its directory with `cjpm run -- ...`.

| Example | Demonstrates | Arguments |
| --- | --- | --- |
| [greet](examples/greet/src/main.cj) | Arguments, defaults, flags and short clusters | `greet Alice -lt2` |
| [sync](examples/sync/src/main.cj) | Variadic paths, repeated options, optional values | `sync src docs -nj4 -x target --exclude=.git` |
| [sub_apps](examples/sub_apps/src/main.cj) | Callback and nested app | `-v project deploy staging` |
| [custom_type](examples/custom_type/src/main.cj) | User-defined enum parsing | `paint --color blue` |

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
- Generic command and callback functions are rejected. Written return types must
  be `Unit` or `Int64`; inferred return types must satisfy the same runtime contract.
- A variadic argument must be the final positional argument. A function overload
  set may have only one `@JianCommand` adapter.
- Optional type aliases keep their CLI behavior, but need an explicit `None`
  default to make named parameters omissible in direct function calls.
