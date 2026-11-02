# Arguments and options

A command is a function. Without extra settings, its positional parameters
become CLI arguments, and its named parameters (`!`) become long options.
Names use kebab case: `dryRun!` becomes `--dry-run`.

Use `JianArgument(...)` and `JianOption(...)` in function parameter defaults
to add CLI settings:

```cangjie
import jian.*

@JianCommand[help: "Greet someone"]
func greet(
    name!: String = JianArgument(help: "Name to greet"),
    times!: Int64 = JianOption(short: 't', help: "Repetitions", default: 1),
    verbose!: Bool = JianOption(short: 'v', default: false)
): Unit {
    for (_ in 0..times) { println(name) }
    if (verbose) { println("Done") }
}
```

The CLI accepts `greet Alice -vt3`. Use `@JianCommand[app]` to register it in a `JianApp`.
The same declarations work under `@JianCallback` for app-level arguments and options.

Cangjie requires `!` on any function parameter with a default expression.
Therefore `name!` above is still a named parameter in direct function calls,
but `JianArgument(...)` makes it positional in the CLI. `JianOption(...)` declares an
option. Bare positional parameters such as `name: String` need no marker.

## Defaults and required values

For the standard supported types:

| Declared type | Explicit default | Behavior when absent from CLI |
| --- | --- | --- |
| `T` | none | Usage error |
| `?T` | none | `None` |
| `T` or `?T` | supplied | Evaluate the default |

This includes flags and arrays. Use `default: false` for a flag that may be
omitted, and `default: []` for an array that may be empty. An optional flag
(`?Bool`) distinguishes absence (`None`) from a supplied flag (`Some(true)`).
Type aliases preserve the underlying type's CLI behavior.

The macros replace markers with their actual defaults. Named function parameters
written as `?T` or `Option<T>` receive `= None` when no default is supplied.
This applies with or without a marker, and `default: None` has the same effect.
Nonoptional parameters without `default` remain required. The example above
retains a function named `greet` with this signature:

```cangjie
func greet(name!: String, times!: Int64 = 1, verbose!: Bool = false): Unit
```

A direct call is `greet(name: "Alice", times: 3)`. Named optional parameters
can also be omitted in direct calls:

```cangjie
@JianCommand
func inspect(value!: ?Int64 = JianOption()) {}

// The function has `value!: ?Int64 = None`.
// Both inspect() and inspect(value: 3) are valid.
```

Macros run before type resolution and cannot identify optional type aliases.
For an alias such as `type MaybeInt = ?Int64`, write `default: None` (or a bare
`= None`) to make it omissible in direct calls. Positional function parameters
without `!` remain positional and require an argument in direct calls.
Defaults remain lazy and can refer to earlier parameters or private names.
Reading a generated command's metadata does not evaluate them. Help metadata
records the default expression without the marker wrapper.

## Settings

Both markers accept named `help: String`, `hidden: Bool`, and `default` of the
declared function parameter type. `JianOption` also accepts a single ASCII literal
for `short`, such as
`'v'`, `"v"`, `r'v'` or `b'v'`. The macro reads its value, so quote normalization
does not change the short name. Short names are unique
within a command or callback, and `'h'` is reserved. Short flags can be clustered, and a value-taking
option accepts attached or separate values (`-t3`, `-t=3`, `-t 3`).

`hidden: true` hides an argument or option from help; parsing still
accepts it. Omitted settings mean empty help, visible, and no short alias.
Unknown or repeated settings, invalid short names, and mistyped defaults or
metadata fail compilation. `JianArgument` does not accept `short`. A variadic
`Array<T>` argument must be the final positional argument.

Markers are recognized as unqualified `JianOption(...)` or `JianArgument(...)` calls
in function parameter defaults; their type comes from the function parameter
declaration.
Runtime marker functions throw `IllegalArgumentException` if evaluated elsewhere.
The standard `Option<T>` type remains available without aliases.

### Input hooks

`JianArgument` and `JianOption` accept three independent typed hooks:

- `preprocess: (String) -> String` transforms each supplied raw token before the
  existing `JianArgValue<T>.accept` conversion. It can trim text before constructing
  a `Path`; the function parameter remains `Path`. Bare flags have no raw token,
  so skip preprocessing; attached flag values are preprocessed normally.
- `normalize: (T) -> T` transforms the final resolved parameter value.
- `validate: (T) -> Unit` checks that normalized value.

For example:

```cangjie
func nonblankPath(raw: String): String {
    let text = raw.trimAscii()
    if (text.isEmpty()) { throw JianInputException("path must not be blank") }
    text
}
func validPort(port: Int64): Unit {
    if (port < 1 || port > 65535) {
        throw JianInputException("port must be between 1 and 65535")
    }
}
@JianCommand
func generate(model!: Path = JianArgument(preprocess: nonblankPath),
    port!: Int64 = JianOption(default: 8080, validate: validPort)): Unit {
    // model is already trimmed and port is valid.
}
```

Import `std.fs.Path` for that example. Hooks accept reusable functions or typed
lambdas, such as `normalize: { value: String => value.toAsciiLower() }`.
Only one hook of each kind is accepted. Incompatible signatures fail compilation.

Parsing accumulates arrays and selects the last occurrence of ordinary options
before final hooks run. Normalization and validation run once per parameter, in
signature order, including explicit defaults and implicit optional `None` values.
An array hook receives the whole final array; an optional hook receives `?T`.
Defaults stay lazy, and later defaults see earlier normalized bindings. Raw
preprocessing runs for every occurrence, even a value later replaced by another.
Missing required inputs fail before their final hooks run.

Throw `JianInputException("explanation")` to reject input from any hook. The
adapter labels the failure with the argument or option name; `JianApp.run` prints
it with usage to stderr and returns 2. Other exceptions propagate unchanged.
Standard conversion still reports its existing `JianInvalidValueException` errors.
The affected callback or command body never executes after rejection. Callback
hooks finish before that callback body and child dispatch; command hooks follow
any parent callbacks in the ordinary dispatch lifecycle.

These hooks apply only to generated CLI adapters for `@JianCommand` and
`@JianCallback`. Ordinary direct calls retain regular defaults and skip all hooks.
Help for an adapter and metadata inspection execute neither its hooks nor defaults.
Ancestor callbacks may already have run before nested help, following the normal
dispatch lifecycle. See the runnable
[`input_hooks` example](../examples/input_hooks/src/main.cj).
