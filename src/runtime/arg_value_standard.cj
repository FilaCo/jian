package jian.runtime

import jian.internal_macros.ArgValueImpl
import std.fs.Path

@ArgValueImpl["TEXT"]
extend String {
    public static func accept(_: ?String, raw: ?String): String { requiredValue(raw) }
}

/**
 * Bool is a flag; a bare occurrence is true, explicit values accept `true` or `false`.
 */
@ArgValueImpl[""]
extend Bool {
    public static func takesValue(): Bool { false }
    public static func accept(_: ?Bool, raw: ?String): Bool {
        if (raw.isNone()) { return true }
        parseValue<Bool>(raw, "Bool")
    }
    public static func whenAbsent(): ?Bool { Some(false) }
}

/**
 * Accepts path text without accessing the filesystem or requiring the path to exist.
 */
@ArgValueImpl["PATH"]
extend Path {
    public static func accept(_: ?Path, raw: ?String): Path { Path(requiredValue(raw)) }
}

@ArgValueImpl[T.metavar()]
extend<T> Option<T> where T <: ArgValue<T> {
    public static func takesValue(): Bool { T.takesValue() }
    public static func accept(prev: ??T, raw: ?String): ?T {
        Some(T.accept(prev ?? None, raw))
    }
    public static func whenAbsent(): ??T { Some(None) }
}

@ArgValueImpl[T.metavar() + "..."]
extend<T> Array<T> where T <: ArgValue<T> {
    public static func takesValue(): Bool { T.takesValue() }
    public static func accept(prev: ?Array<T>, raw: ?String): Array<T> {
        // Each occurrence starts a new element; only the outer array accumulates.
        (prev ?? []).concat([T.accept(None, raw)])
    }
    public static func whenAbsent(): ?Array<T> { Some([]) }
}
