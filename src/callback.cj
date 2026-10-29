macro package jian

import std.ast.*

/**
 * Preserves the function and generates a typed adapter for app-level CLI parsing.
 * An optional positional app registers the callback; a second callback is rejected.
 * Without an app, register the function explicitly with app.callback(configure).
 * Parses declared positional arguments and options, stopping before the command name.
 * Returns JianCallbackResult: Continue dispatches, Exit(code) returns from app.run.
 * The return type may be inferred; exceptions propagate through app.run.
 * Supports the same value types, defaults and `help` setting as `@JianCommand`.
 * JianFromContext<C>() parameters receive dependencies from the context supplied to run.
 * JianCurrentInvocation() injects JianInvocation after parsing, without creating a CLI input;
 * direct callers must supply it explicitly. requestedSubcommand may name an unknown command.
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
