# Typed context

A context carries dependencies that do not come from CLI arguments and options.
Annotate a nongeneric class with `@JianContext` and explicitly type its instance
fields. Fields in a primary constructor work too. Private fields can be injected;
their visibility does not change. Static fields, properties and inherited fields
are not automatically injected.

```cangjie
@JianContext
class AppContext {
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

Use `JianFromContext<C>()` as the default of a named function parameter in a
`@JianCommand` or `@JianCallback` declaration:

```cangjie
@JianCommand
func greet(name: String, logger!: Logger = JianFromContext<AppContext>()): Unit {
    logger.greet(name)
}

@JianCallback
func configure(ctx!: AppContext = JianFromContext<AppContext>(), verbose!: Bool = false): Unit {
    ctx.verbose = verbose
}
```

The marker takes exactly one context type and no arguments. A parameter's declared
type selects the dependency; it need not implement `JianArgValue`. Request the
context's own type to receive that same object. Multiple parameters may request
the same field type. `Option<T>` is an ordinary dependency type: it requires a
field of that type, and is not implicitly unwrapped or created.

All injections in one function must spell the same context type. An imported
alias can be used consistently in all markers and app wiring. The generated
adapter has the function's visibility, so internal functions can use internal
context types; public functions require publicly accessible signature types.

The macro removes injection defaults from the original function. Explicit direct
calls therefore supply the dependencies, including optional dependencies:

```cangjie
greet("Alice", logger: logger)
configure(ctx: context, verbose: true)
```

Injected parameters do not create CLI inputs, storage in the argument parser,
metadata, usage placeholders or help rows. Dependencies are extracted after CLI
parsing, in parameter declaration order alongside other parameter bindings.
Defaults can refer to earlier injected parameters. Extraction returns each field
as it exists at invocation time, without caching. Class-valued fields retain
object identity; other values follow Cangjie's normal value semantics.

## Wire and run the app

```cangjie
let context = AppContext(logger)
let people = JianApp<AppContext>(name: "people").add(GreetCommand())
let app = JianApp<AppContext>(name: "demo")
    .callback(ConfigureCallback())
    .add(people)

app.run(["--verbose", "people", "greet", "Alice"], context: context)
```

`JianApp<C>` accepts generated `JianContextCommand<C>` and
`JianContextCallback<C>` adapters, as well as ordinary `JianCommand` and
`JianCallback` implementations that ignore the context. A hand-written context
adapter exposes the usual `spec` (and command `name`) and implements
`run(args: JianArgCursor, context: C): Int64`.

Every sub-app must be a `JianApp<C>` with the same context type, even if
none of its functions requests a dependency. It receives the context supplied to
the root run, full command path and root output streams. Sub-apps cannot introduce
or replace a context. Apps without injection use `JianApp<Unit>` and can call
`run(argv)` without supplying context. They cannot register adapters requiring
another context type. A mismatched command, callback or sub-app,
a missing dependency implementation, and a `run` call without context fail to
compile. Multiple context types in one tree are not supported in this version.

Create and own the context outside callbacks and commands. Each `run` requires an
explicit context; the app stores no context between calls. Reusing an object
preserves its mutations, while supplying a new object gives independent state.
App instances share state only when the caller deliberately supplies shared
objects. The caller also owns resource cleanup. Concurrent runs on a shared
mutable context need the application's own synchronization.

Callbacks receive an existing context, return `Unit` or `Int64`, and execute from
root to leaf before the selected command. Mutations are visible to later
callbacks and commands. A nonzero callback result stops dispatch; mutations are
not rolled back. A callback-only app can configure context without a command.

Help skips the callback or command whose help is requested; ancestor callbacks
may already have run. No dependencies are extracted for the skipped target.
Help returns 0. Usage errors return 2 with usage on stderr. Other exceptions
propagate for both context-bearing and context-free apps.

Existing context-free applications migrate from `JianApp(name: ...)` to
`JianApp<Unit>(name: ...)`; their `run(argv)` calls stay the same. Applications
with context use `JianApp<C>(name: ...)` and `run(argv, context: value)`.

## Generated extraction contract

`@JianContext` generates a local `FromAppContext<T>` interface with the static
method `fromContext(context: AppContext): T`, plus an extension implementing it
for every field type and for `AppContext` itself. Defining the interface in the
context's package permits extensions of dependency types from other libraries.

A generated static `AppContext.jianFromContext<T>(context)` method constrains
`T <: FromAppContext<T>`. Command and callback adapters call that method, so
context aliases work without reconstructing generated interface names. All
extraction is checked statically; there are no runtime casts or dependency maps.
The generated names are implementation details, and users only need
`import jian.*` and imports for their own types.
