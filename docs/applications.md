# Applications and composition

`JianApp` is an application without injected dependencies. `JianContextApp<C>`
requires a context on each run. Both support command registration, one callback,
help and nested groups. An app without an explicit `name` uses `app` in standalone
help and usage. A command keeps its name even if it is the app's only command.

## Registration

```cangjie
let app = JianApp(name: "demo")

@JianCommand[app, help: "Create a user."]
func create(name: String): Unit {
    println("Creating ${name}")
}

@JianCallback[app]
func configure(verbose!: Bool = false): JianCallbackResult {
    if (verbose) { println("Verbose mode enabled") }
    JianCallbackResult.Continue
}

main(args: Array<String>): Int64 { app.run(args) }
```

The macros preserve each function's name, parameter types, named arguments and
defaults. They also generate a typed CLI adapter and one registration overload
with a required tag parameter. The expected type in `.add(create)` or
`.callback(configure)` selects that overload automatically. Registration never
calls the function body or evaluates its defaults.

The optional first positional macro argument selects the registration app;
`help:` is a named setting. Named `app:` is not accepted. The app must be
initialized before automatic registration. In the same file, declare it first.
A second callback or a conflicting command/group name throws
`IllegalArgumentException` during assembly. With global registration, that error
occurs during program initialization, before `main`.

To attach a command separately, omit the app from its macro:

```cangjie
@JianCommand[help: "Create a user."]
func create(name: String, verbose!: Bool = false): Unit {
    println(name)
    if (verbose) { println("Verbose mode enabled") }
}

let users = JianApp().add(create)
let admins = JianApp().add(create)

// Direct calls skip CLI parsing and preserve defaults.
create("Alice")
create("Alice", verbose: true)
```

Callbacks work the same way: `app.callback(configure)` registers the annotated
function. The same function can be registered in independent apps. Register it
only once in a given app.

When taking a function value, provide its type to select the ordinary overload:
`let action: (String, Bool) -> Unit = create`. Defaults belong to direct function
calls, so a function value takes all its parameters. Recursive bodies call
`create(...)` normally, and functions may be called before their declaration.
The function and registration overload retain the original visibility.

The generated adapter remains available as `CreateCommand()` (or
`ConfigureCallback()`) when explicit access to CLI metadata or parsing is needed.
The registration tag types are implementation details; ordinary calls do not
supply them.

## Callback completion

Callbacks must return `JianCallbackResult`. The return type may be inferred from
`Continue` or `Exit(code)`; `Unit` and `Int64` are not accepted. Commands continue
to return `Unit` or `Int64`.

Use `Continue` for ordinary setup. Use `Exit(code)` to return immediately from
`app.run`, before selecting a command or requiring its name. `Exit(0)` permits
options such as `--config-schema` alongside named subcommands:

```cangjie
@JianCallback[app]
func configure(configSchema!: Bool = false) {
    if (configSchema) {
        printConfigSchema()
        return JianCallbackResult.Exit(0)
    }
    JianCallbackResult.Continue
}
```

Here `printConfigSchema()` is application code. `demo --config-schema` completes
successfully without a subcommand. `demo --config-schema fetch-src` also completes
without invoking `fetch-src`. `demo fetch-src` proceeds to that command normally.
An `Exit` skips all remaining dispatch, including validation of a subcommand name
or its inputs. With `Continue`, missing and unknown commands retain their usual
errors; a callback-only app still succeeds without a command.

This is ordinary callback execution: its arguments and options are parsed and
validated before its body runs. Required callback inputs must still be supplied.
`--help` and `-h` show help without invoking the target callback. Ancestor callbacks
may already have run for nested help.

For nested apps, `Exit(code)` returns through the root `run`; later callbacks,
commands and child context projections are skipped. The library does not terminate
the process or close the caller's streams. A thrown `JianUsageException` produces
the normal usage error and code 2; other exceptions propagate to the caller.
See the runnable [callback exit example](../examples/callback_exit/src/main.cj).

## Mounts

```cangjie
let users = JianApp(help: "User management.")
let app = JianApp(name: "demo")
    .add(users, name: "users")
    .add(users, name: "admins", help: "Administrator management.")
```

`add(child, name: ..., help: ...)` returns the parent. Each mount owns its name
and optional help override, including the help shown when entering that group.
The child's standalone name and help do not change. Without an override, the
mount uses the child's help.

Mounts retain the child, including registrations added later. Reusing the same
child under several paths shares its registry and any state deliberately used
by its handlers. Duplicate names and direct or indirect cycles are rejected.
Finish assembly before running; mutating an app while it runs is unsupported.

Arguments and options belong to their own level:

```text
demo --verbose users --tenant acme create Alice --force
```

Here `--verbose` belongs to the root callback, `--tenant` to the users callback,
and `--force` to the command. Callbacks run root to leaf; `Continue` proceeds
with dispatch and `Exit(code)` stops execution, including code 0. Help skips its
target, although ancestor callbacks may have run.
Nested help and errors use the full mount path and the root's output streams.

## Files and packages

An app and its handlers can occupy different files of the same package:

```cangjie
// users/app.cj
package demo.users
import jian.*
public let app = JianApp(help: "Users")
```

```cangjie
// users/create.cj
package demo.users
import jian.*

@JianCommand[app]
func create(name: String): Unit {
    println(name)
}
```

The executable imports only the app; the command functions need not be public:

```cangjie
package demo
import jian.*
import demo.users.app as users

let app = JianApp(name: "demo").add(users, name: "users")
main(args: Array<String>): Int64 { app.run(args) }
```

To export an individual command function for explicit registration, mark its declaration
`public`. Consumers can import that function and pass it to `.add(create)` or invoke
`create(...)`. The [sub-app example](../examples/sub_apps/src/main.cj) registers
an imported `deploy` function at the root as well as in its original project app.

A separate package can also import that app and register additional handlers.
The executable must import that extra package, directly or transitively, for its
initializers to run. Merely compiling a package does not activate it. Avoid import
cycles: keep shared app declarations separate from packages that assemble them.
Independent packages must not rely on registration order; help sorts entries by
name. Do not execute the CLI in global initializers; run it from `main` after
registration has completed.

## Contexts

A `JianContextApp<P>` accepts a `JianApp` child without extracting dependencies.
For a `JianContextApp<C>` child it either passes the same context type unchanged
or requires `C <: FromParentContext<C>` for the actual parent context type.
`@JianContext` generates extraction for each direct field and the context itself.
Import the context package with `*` to bring its generated composition interface
into scope. A `JianApp` cannot mount a context-bearing child.

Extraction happens on entry to the selected child, after the parent's callback,
and is repeated for every run. The parent context need not recursively expose
every dependency of its children. Each child handles injection from its own
context. See [Typed context](context.md) and the multi-package
[context example](../examples/context/src/main.cj).
