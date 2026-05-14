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
    | Comma // `,`.
    | Eq // `=`.
    | StdinPlaceholder // `-` surrounded by whitespaces.
    | Dashed // Dashed option, e.g. `-f` or `-vvv`.
    | DoubleDashed // Double dashed option, e.g. `--foo`.
    | Value // Arbitrary string value.
    | EOI // End of input.
}
