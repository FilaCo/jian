macro package jian

import std.ast.*

/**
 * Marks a function as the app-level callback, run before a subcommand.
 * Accepts metadata attributes, such as `@Callback[help: "App options."]`.
 * Currently a pass-through stub.
 */
public macro Callback(attrs: Tokens, input: Tokens): Tokens {
    input
}

/**
 * Marks a function as the app-level callback without metadata attributes.
 * Currently a pass-through stub.
 */
public macro Callback(input: Tokens): Tokens {
    input
}
