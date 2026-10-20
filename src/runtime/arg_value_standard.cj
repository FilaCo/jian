package jian.runtime

import std.fs.Path

extend String <: ArgValue<String> {
    public static func takesValue(): Bool { true }
    public static func metavar(): String { "TEXT" }
    public static func accept(_: ?String, raw: ?String): String { requiredValue(raw) }
    public static func whenAbsent(): ?String { None }
}

/** Bool is a flag; a bare occurrence is true, explicit values accept `true` or `false`. */
extend Bool <: ArgValue<Bool> {
    public static func takesValue(): Bool { false }
    public static func metavar(): String { "" }
    public static func accept(_: ?Bool, raw: ?String): Bool {
        if (raw.isNone()) { return true }
        parseValue<Bool>(raw, "Bool")
    }
    public static func whenAbsent(): ?Bool { Some(false) }
}

/** Accepts path text without accessing the filesystem or requiring the path to exist. */
extend Path <: ArgValue<Path> {
    public static func takesValue(): Bool { true }
    public static func metavar(): String { "PATH" }
    public static func accept(_: ?Path, raw: ?String): Path { Path(requiredValue(raw)) }
    public static func whenAbsent(): ?Path { None }
}

extend<T> Option<T> <: ArgValue<Option<T>> where T <: ArgValue<T> {
    public static func takesValue(): Bool { T.takesValue() }
    public static func metavar(): String { T.metavar() }
    public static func accept(prev: ??T, raw: ?String): ?T {
        Some(T.accept(prev ?? None, raw))
    }
    public static func whenAbsent(): ??T { Some(None) }
}

extend<T> Array<T> <: ArgValue<Array<T>> where T <: ArgValue<T> {
    public static func takesValue(): Bool { T.takesValue() }
    public static func metavar(): String { T.metavar() + "..." }
    public static func accept(prev: ?Array<T>, raw: ?String): Array<T> {
        // Each occurrence starts a new element; only the outer array accumulates.
        (prev ?? []).concat([T.accept(None, raw)])
    }
    public static func whenAbsent(): ?Array<T> { Some([]) }
}
