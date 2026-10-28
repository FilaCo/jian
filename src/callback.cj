macro package jian

import std.ast.*

/**
 * Generates a typed app-level adapter that runs before a subcommand.
 * A function `configure` produces `ConfigureCallback`, registered with `App.callback`.
 * Parses declared positional parameters and options, stopping before the command name.
 * Supports the same parameter types, defaults and `help` setting as `@Command`.
 */
public macro Callback(attrs: Tokens, input: Tokens): Tokens {
    commandAdapter(attrs, input, callback: true)
}

/**
 * Attribute-free form of `@Callback`.
 */
public macro Callback(input: Tokens): Tokens {
    commandAdapter(Tokens(), input, callback: true)
}
