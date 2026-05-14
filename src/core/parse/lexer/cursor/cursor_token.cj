protected package jian.core.parse.lexer.cursor

import std.deriving.*

@Derive[Equatable, ToString]
struct CursorToken {
    CursorToken(let kind: CursorTokenKind, let size: Int64) {}

    static func eoi(): CursorToken {
        CursorToken(EOI, 0)
    }
}

@Derive[Equatable, ToString]
enum CursorTokenKind {
    | WS // Any whitespace character sequence.
    | StdinPlaceholder // `-` surrounded by whitespaces.
    | Eq // `=`.
    | Dashed
    | DoubleDashed
    | Value // Arbitrary string
    | EOI
}
