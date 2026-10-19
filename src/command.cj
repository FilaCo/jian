macro package jian

import std.ast.* // cjlint-ignore !G.PKG.01

/**
 * Turns a function into a CLI command.
 *
 * A pass-through stub for now: the generated `Command` implementation comes in #13.
 */
public macro Command(attrs: Tokens, input: Tokens): Tokens { // cjlint-ignore !G.FUN.02
    input
}

public macro Command(input: Tokens): Tokens {
    input
}
