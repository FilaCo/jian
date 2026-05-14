protected package jian.core.parse.lexer

import std.deriving.*

@Derive[Equatable, ToString]
enum Token {
    | Eq // `=`.
    | DoubleDashed(String) // Value prefixed with `--`, e.g. `--foo`.
    | Dashed(String) // Value prefixed with `-`, e.g. `-f` or `-vvv`.
    | Value(String) // Arbitrary value, e.g. `foo`.
    | Dummy
    | EOI // End of input.
}
