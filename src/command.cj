macro package jian

import std.ast.*

/**
 * Turns a function into a CLI command.
 */
public macro Command(attrs: Tokens, input: Tokens): Tokens {
    input
}

/**
 * Turns a function into a CLI command.
 */
public macro Command(input: Tokens): Tokens {
    input
}
