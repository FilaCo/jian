package jian.runtime

/**
 * Declares a CLI option in a @JianCommand or @JianCallback function parameter default.
 * The macro replaces the marker with its default. Named `?T` and `Option<T>` parameters
 * default to None without an explicit default; nonoptional parameters remain required.
 * `short` must be a single ASCII literal other than 'h'; hidden options still parse.
 * Throws IllegalArgumentException if evaluated outside macro processing.
 */
public func JianOption<T>(default!: ?T = None, short!: ?Rune = None,
    help!: String = "", hidden!: Bool = false): T {
    let _ = (default, short, help, hidden)
    throw IllegalArgumentException("JianOption must be a function parameter default in @JianCommand or @JianCallback")
}

/**
 * Declares a positional CLI argument in a @JianCommand or @JianCallback function parameter default.
 * Cangjie requires `!` on function parameters with defaults; CLI position comes from this marker.
 * The macro replaces the marker with its default, using None for `?T` and `Option<T>`.
 * Nonoptional parameters without a default remain required. Hidden arguments still parse.
 * Throws IllegalArgumentException if evaluated outside macro processing.
 */
public func JianArgument<T>(default!: ?T = None, help!: String = "", hidden!: Bool = false): T {
    let _ = (default, help, hidden)
    throw IllegalArgumentException("JianArgument must be a function parameter default in @JianCommand or @JianCallback")
}
