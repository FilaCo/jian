macro package jian

import std.ast.*

/**
 * CLI command declaration; currently a pass-through stub.
 */
public macro Command(attrs: Tokens, input: Tokens): Tokens {
    input
}

/**
 * Attribute-free form of `@Command`.
 */
public macro Command(input: Tokens): Tokens {
    input
}
