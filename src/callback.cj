macro package jian

import std.ast.*

/**
 * App-level callback run before a subcommand; currently a pass-through stub.
 */
public macro Callback(attrs: Tokens, input: Tokens): Tokens {
    input
}

/**
 * Attribute-free form of `@Callback`.
 */
public macro Callback(input: Tokens): Tokens {
    input
}
