package jian.runtime

/**
 * Declares a CLI option in a @Command or @Callback parameter default.
 * The macro replaces this marker with `default`, or removes the default when omitted.
 * `short` must be a single ASCII literal other than 'h'; hidden options still parse.
 * Throws IllegalArgumentException if evaluated outside macro processing.
 */
public func Option<T>(short!: ?Rune = None, help!: String = "", hidden!: Bool = false): T {
    let _ = (short, help, hidden)
    throw IllegalArgumentException("Option must be a parameter default in @Command or @Callback")
}

/** Declares an option with a lazy default expression; throws if evaluated. */
public func Option<T>(default!: T, short!: ?Rune = None, help!: String = "", hidden!: Bool = false): T {
    let _ = (default, short, help, hidden)
    throw IllegalArgumentException("Option must be a parameter default in @Command or @Callback")
}

/**
 * Declares a positional CLI argument in a @Command or @Callback parameter default.
 * Cangjie requires `!` on function parameters with defaults; CLI position comes from this marker.
 * The macro removes the marker, retaining only an explicitly supplied `default`.
 * Hidden arguments still parse. Throws IllegalArgumentException if evaluated otherwise.
 */
public func Argument<T>(help!: String = "", hidden!: Bool = false): T {
    let _ = (help, hidden)
    throw IllegalArgumentException("Argument must be a parameter default in @Command or @Callback")
}

/** Declares a positional argument with a lazy default expression; throws if evaluated. */
public func Argument<T>(default!: T, help!: String = "", hidden!: Bool = false): T {
    let _ = (default, help, hidden)
    throw IllegalArgumentException("Argument must be a parameter default in @Command or @Callback")
}
