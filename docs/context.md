# Typed context

A context carries dependencies that do not come from CLI arguments and options.
Annotate a nongeneric class with `@JianContext` and explicitly type its instance
fields. Fields in a primary constructor work too. Private fields can be injected;
their visibility does not change. Static fields, properties and inherited fields
are not automatically injected.

```cangjie
@JianContext
class UsersContext {
    public let logger: Logger
    public var verbose: Bool = false

    public init(logger: Logger) { this.logger = logger }
}
```

Each field type must be unique, including aliases for the same type. Use distinct
wrapper types when two dependencies have the same underlying type. A field with
the context's own type also conflicts with injection of the whole context.
There is no recursive search through nested fields or lookup by parameter name.

## Request dependencies

Use `JianFromContext<C>()` as the default of a named function parameter:

```cangjie
let users = JianContextApp<UsersContext>()

@JianCommand[users]
func greet(name: String, logger!: Logger = JianFromContext<UsersContext>()): Unit {
    logger.greet(name)
}

@JianCallback[users]
func configure(ctx!: UsersContext = JianFromContext<UsersContext>(), verbose!: Bool = false): JianCallbackResult {
    ctx.verbose = verbose
    JianCallbackResult.Continue
}
```

The marker takes exactly one context type and no arguments. A parameter's declared
type selects the dependency; it need not implement `JianArgValue`. Request the
context's own type to receive that same object. Multiple parameters may request
the same field type. `Option<T>` is an ordinary dependency type: it requires a
field of that type, and is not implicitly unwrapped or created.

All injections in one function must spell the same context type. An imported
alias can be used consistently in all markers and app wiring. The command/callback
function and its generated adapter have the declaration's visibility. Internal
functions can use internal context types; public functions require publicly
accessible signature types.
A command or callback with injection must match its registration app's context.
Context-free handlers can register in either app type.

The macro removes injection defaults from the function signature. Direct calls
therefore supply dependencies explicitly, including optional dependencies:

```cangjie
greet("Alice", logger: logger)
configure(ctx: context, verbose: true)
```

Injected parameters create no CLI inputs, parser storage, metadata or help rows.
Dependencies are extracted after parsing, in parameter declaration order alongside
other bindings. Defaults can refer to earlier injected parameters. Extraction
returns each field at invocation time, without caching. Class-valued fields retain
object identity; other values follow Cangjie's normal value semantics.

## Compose different contexts

```cangjie
@JianContext
class AppContext {
    public let users: UsersContext
    public init(users: UsersContext) { this.users = users }
}

let app = JianContextApp<AppContext>(name: "demo")
    .add(users, name: "users")

main(args: Array<String>): Int64 {
    app.run(args, context: AppContext(UsersContext(Logger())))
}
```

The parent callback receives `AppContext`. On entry to `users`, the app extracts
`UsersContext` from the parent's field, then runs the child callback and command
with it. The parent need not expose `Logger` directly. Extraction is repeated on
each selected entry after the parent callback, so mutations or replacement of the
child field are visible. There is no implicit recursive field search: each mount
checks its own parent-to-child transition.

The compile-time rule is `ChildContext <: FromParentContext<ChildContext>`, with
the interface generated for the actual parent. The same context type is passed
unchanged. `JianApp` children ignore their parent's context; `JianApp` parents
cannot mount a `JianContextApp<C>`. A missing extraction, mismatched handler,
missing dependency, or typed `run` without context fails to compile.

When contexts live in another package, import that package with `*` for automatic
composition. This imports the generated local composition interface as well as
the context types. The [context example](../examples/context/src/main.cj) exercises
separate app, handler, dependency and context packages.

For explicit transformations, a typed app also supports
`.add(child, name: "users", context: { parent: AppContext => parent.users })`.
This evaluates the supplied projection at child entry, following the same lifetime
rules, and is useful when automatic extraction is unsuitable.

## Lifetime and execution

Create and own the context outside callbacks and commands. `JianContextApp<C>`
requires `run(argv, context: value)` on every invocation and stores no context
between runs. Reusing an object preserves mutations; a new object gives independent
state. The caller owns resource cleanup and synchronization for concurrent use
of shared mutable context.

Callbacks return `JianCallbackResult` and run root to leaf. `Continue` proceeds
with dispatch; `Exit(code)` returns immediately from the root `run`, including
code 0, without entering further children or extracting their contexts. The
return type may be inferred. Mutations are not rolled back. A callback-only app
can run without a command. Help skips the target callback/command; ancestor
callbacks and context projections may already have run. Help returns 0, usage
errors return 2, and other exceptions propagate.

## Generated contracts

`@JianContext` generates a local `FromAppContext<T>` interface with the static
method `fromContext(context: AppContext): T`, plus an extension implementing it
for every field type and for `AppContext` itself. The local interface permits
extensions of dependency types from other libraries, including standard types.

A generated static `AppContext.jianFromContext<T>(context)` method constrains
`T <: FromAppContext<T>`. Handlers call this method, so context aliases work
without reconstructing generated names.

A local `AppsFromAppContext` interface exports the generated mount overload on
`JianContextApp<AppContext>`. Its defaulted parent tag distinguishes overloads for
different parent contexts and is an implementation detail. All extraction is
checked statically, without runtime casts or dependency maps.
