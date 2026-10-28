macro package jian

import std.ast.*

/**
 * Generates a typed app-level adapter that runs before a subcommand.
 * A function `configure` produces `ConfigureCallback`, registered with `JianApp.callback`.
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
