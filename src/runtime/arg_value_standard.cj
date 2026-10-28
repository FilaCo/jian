package jian.runtime

import jian.runtime.macros.ArgValues
import std.fs.Path

@ArgValues(
    value<String>(metavar: "TEXT", accept: requiredValue(raw)),
    // Paths remain textual without checking the filesystem.
    value<Path>(metavar: "PATH", accept: Path(requiredValue(raw))),
    value<Bool>(
        takesValue: false,
        accept: if (raw.isNone()) { true } else { parseValue<Bool>(raw, "Bool") }
    )
)

@ArgValues[T](
    value<Option<T>>(
        metavar: T.metavar(),
        takesValue: T.takesValue(),
        whenAbsent: Some(None),
        accept: Some(T.accept(prev ?? None, raw))
    ),
    value<Array<T>>(
        metavar: T.metavar() + "...",
        takesValue: T.takesValue(),
        // Each occurrence starts a new element; only the outer array accumulates.
        accept: (prev ?? []).concat([T.accept(None, raw)])
    )
)
