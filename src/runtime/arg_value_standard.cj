package jian.runtime

import jian.runtime.macros.ArgValues
import std.fs.Path

// Paths remain textual; a bare boolean flag means true.
@ArgValues(
    (String, "TEXT", true, None, requiredValue(raw)),
    (Path, "PATH", true, None, Path(requiredValue(raw))),
    (Bool, "", false, Some(false), if (raw.isNone()) { true } else { parseValue<Bool>(raw, "Bool") })
)

// Each array occurrence starts a new element; only the outer array accumulates.
@ArgValues[T](
    (Option<T>, T.metavar(), T.takesValue(), Some(None), Some(T.accept(prev ?? None, raw))),
    (Array<T>, T.metavar() + "...", T.takesValue(), Some([]), (prev ?? []).concat([T.accept(None, raw)]))
)
