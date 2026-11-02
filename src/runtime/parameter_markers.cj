package jian.runtime

/**
 * Declares a CLI option in a @JianCommand or @JianCallback function parameter default.
 * The macro replaces the marker with its default. Named `?T` and `Option<T>` parameters
 * default to None without an explicit default; nonoptional parameters remain required.
 * `short` must be a single ASCII literal other than 'h'; hidden options still parse.
 * `preprocess` transforms supplied raw text; `normalize` then `validate` process the final T,
 * including defaults, None and whole arrays. Throw JianInputException to report a usage error.
 * Direct calls bypass hooks. Throws IllegalArgumentException if evaluated outside macro processing.
 */
public func JianOption<T>(default!: ?T = None, short!: ?Rune = None,
    help!: String = "", hidden!: Bool = false, preprocess!: ?((String) -> String) = None,
    normalize!: ?((T) -> T) = None, validate!: ?((T) -> Unit) = None): T {
    let _ = (default, short, help, hidden, preprocess, normalize, validate)
    throw IllegalArgumentException("JianOption must be a function parameter default in @JianCommand or @JianCallback")
}

/**
 * Declares a positional CLI argument in a @JianCommand or @JianCallback function parameter default.
 * Cangjie requires `!` on function parameters with defaults; CLI position comes from this marker.
 * The macro replaces the marker with its default, using None for `?T` and `Option<T>`.
 * Nonoptional parameters without a default remain required. Hidden arguments still parse.
 * `preprocess` transforms supplied raw text; `normalize` then `validate` process the final T,
 * including defaults, None and whole arrays. Throw JianInputException to report a usage error.
 * Direct calls bypass hooks. Throws IllegalArgumentException if evaluated outside macro processing.
 */
public func JianArgument<T>(default!: ?T = None, help!: String = "", hidden!: Bool = false,
    preprocess!: ?((String) -> String) = None,
    normalize!: ?((T) -> T) = None, validate!: ?((T) -> Unit) = None): T {
    let _ = (default, help, hidden, preprocess, normalize, validate)
    throw IllegalArgumentException("JianArgument must be a function parameter default in @JianCommand or @JianCallback")
}

/**
 * Injects a dependency from context C into a @JianCommand or @JianCallback parameter.
 * Its declared parameter type selects the dependency. The macro removes the default,
 * so direct callers must supply it. No CLI input is created.
 * Throws IllegalArgumentException if evaluated outside macro processing.
 */
public func JianFromContext<C>(): C {
    throw IllegalArgumentException("JianFromContext must be a function parameter default in @JianCommand or @JianCallback")
}
