macro package jian

import std.ast.*

/**
 * Generates a typed callback value with a call method and app-level CLI parsing.
 * An optional positional app registers the callback; a second callback is rejected.
 * Without an app, attach the value explicitly with app.callback(configure).
 * Parses declared positional arguments and options, stopping before the command name.
 * Supports the same value types, defaults and `help` setting as `@JianCommand`.
 * JianFromContext<C>() parameters receive dependencies from the context supplied to run.
 */
public macro JianCallback(attrs: Tokens, input: Tokens): Tokens {
    commandAdapter(attrs, input, callback: true)
}

/**
 * Attribute-free form of `@JianCallback`.
 */
public macro JianCallback(input: Tokens): Tokens {
    commandAdapter(Tokens(), input, callback: true)
}
