# Parameter declarations

A command is a function. Without extra settings, its positional parameters
become CLI arguments, and its named parameters (`!`) become long options.
Names use kebab case: `dryRun!` becomes `--dry-run`.

Use `Argument(...)` and `Option(...)` in parameter defaults to add CLI settings:

```cangjie
import jian.*

@Command[help: "Greet someone"]
func greet(
    name!: String = Argument(help: "Name to greet"),
    times!: Int64 = Option(short: 't', help: "Repetitions", default: 1),
    verbose!: Bool = Option(short: 'v', default: false)
): Unit {
    for (_ in 0..times) { println(name) }
    if (verbose) { println("Done") }
}
```

The CLI accepts `greet Alice -vt3`. Register `GreetCommand()` with `App`.
The same declarations work under `@Callback` for app-level parameters.

Cangjie requires `!` on any function parameter with a default expression.
Therefore `name!` above is still a named parameter in direct function calls,
but `Argument(...)` makes it positional in the CLI. `Option(...)` declares an
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
Type aliases preserve the underlying type's behavior.

The macros replace markers with their actual defaults. Without `default`,
they remove the default expression altogether. The example above becomes an
ordinary function with this signature:

```cangjie
func greet(name!: String, times!: Int64 = 1, verbose!: Bool = false): Unit
```

A direct call is `greet(name: "Alice", times: 3)`. Only explicit defaults can
be omitted in direct function calls; the CLI also applies `?T` absence behavior.
Defaults remain lazy and can refer to earlier parameters or private names.
Reading a generated command's metadata does not evaluate them. Help metadata
records the default expression without the marker wrapper.

## Settings

Both markers accept named `help: String`, `hidden: Bool`, and `default` of the
declared parameter type. `Option` also accepts `short: Rune`: a single ASCII
character literal such as `'v'`. Short names are unique within a command or
callback, and `'h'` is reserved. Short flags can be clustered, and a value-taking
option accepts attached or separate values (`-t3`, `-t=3`, `-t 3`).

`hidden: true` hides a parameter from help metadata consumers; parsing still
accepts it. Omitted settings mean empty help, visible, and no short alias.
Unknown or repeated settings, invalid short names, and mistyped defaults or
metadata fail compilation. `Argument` does not accept `short`. A variadic
`Array<T>` argument must be the final positional argument.

Markers are recognized as unqualified `Option(...)` or `Argument(...)` calls
in parameter defaults; their type comes from the parameter declaration.
Runtime marker functions throw `IllegalArgumentException` if evaluated elsewhere.
`Option` shares its name with `std.core.Option`; outside marker declarations,
use an explicit import or alias to disambiguate value expressions, for example
`import std.core.Option as Optional` for `Optional<Int64>.whenAbsent()`.
The optional type spelling `?T` needs no alias.
