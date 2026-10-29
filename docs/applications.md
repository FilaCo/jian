# Applications and composition

`JianApp` is an application without injected dependencies. `JianContextApp<C>`
requires a context on each run. Both support command registration, one callback,
help and nested groups. An app without an explicit `name` uses `app` in standalone
help and usage. A command keeps its name even if it is the app's only command.

## Registration

```cangjie
let app = JianApp(name: "demo")

@JianCommand[app: app, help: "Create a user."]
func create(name: String): Unit {
    println("Creating ${name}")
}

@JianCallback[app: app]
func configure(verbose!: Bool = false): Unit {
    if (verbose) { println("Verbose mode enabled") }
}

main(args: Array<String>): Int64 { app.run(args) }
```

The macros preserve the ordinary functions, rewrite parameter markers as before,
and emit an adapter plus a global initializer that registers it. Registration
never calls the function or evaluates its parameter defaults. Direct calls keep
their typed signatures and defaults; functions can still be passed as values.

Macro settings are named: `app:` selects the application and `help:` supplies the
description. The top-level app must be initialized before registration. In the
same file, declare the app first. A second callback or a conflicting command/group
name throws `IllegalArgumentException` during assembly. With global registration,
that error occurs during program initialization, before `main`.

Without `app:`, `@JianCommand` and `@JianCallback` still generate adapters for
explicit assembly, such as `app.add(CreateCommand())` and
`app.callback(ConfigureCallback())`. Register each adapter only once. This also
allows callers to build independent app instances without shared global apps.

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
and `--force` to the command. Callbacks run root to leaf; a nonzero result stops
execution. Help skips its target, although ancestor callbacks may have run.
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

@JianCommand[app: app]
func create(name: String): Unit {
    println(name)
}
```

The executable imports only the app; the handlers need not be public:

```cangjie
package demo
import jian.*
import demo.users.app as users

let app = JianApp(name: "demo").add(users, name: "users")
main(args: Array<String>): Int64 { app.run(args) }
```

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

## Migration

- Replace `JianApp<JianNoContext>` / `JianApp<Unit>` with `JianApp`.
- Replace context-bearing `JianApp<C>` with `JianContextApp<C>`.
- Move each group name from the child constructor to `.add(child, name: ...)`.
- Prefer `@JianCommand[app: app]` and `@JianCallback[app: app]` over manual adapters.
- Callback registration now rejects duplicates instead of replacing the callback.
