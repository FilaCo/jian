macro package jian

import std.ast.* // cjlint-ignore !G.PKG.01

/**
 * Turns a function into the app-level options of an `App`, run before its subcommand.
 *
 * A pass-through stub for now: the generated `Callback` implementation comes in #19.
 */
public macro Callback(attrs: Tokens, input: Tokens): Tokens { // cjlint-ignore !G.FUN.02
    input
}

public macro Callback(input: Tokens): Tokens {
    input
}
