protected package jian.core.parse.lexer

import jian.core.parse.lexer.cursor.Cursor

class Lexer {
    private Lexer(private let cursor: Cursor, private var bytePos: Int64, private var curToken: Token) {}

    static func make(input: String): Lexer {
        let lexer = Lexer(Cursor(input), 0, Dummy)
        let _ = lexer.bump()
        lexer.bytePos = 0

        lexer
    }

    func peek(): Token {
        curToken
    }

    func bump(): Token {
        // if (curItem == "--") {
        //     return EOI
        // }

        // match (curItem[0]) {
        //     case b'-' where curItem[1] == b'-' => doubleDashed(curItem)
        //     case b'-' => dashed(curItem)
        //     case _ => Value(curItem)
        // }
        Dummy
    }

    private func nextTokenFromCursor(): Token {
        Dummy
    }
}
