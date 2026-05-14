protected package jian.core.parse.lexer

class Lexer {
    private Lexer(private let input: Array<String>, private var pos: Int64, private var curToken: Token) {}

    static func make(input: Array<String>): Lexer {
        let lexer = Lexer(input, 0, Dummy)
        let _ = lexer.bump()
        lexer.pos = 0

        lexer
    }

    func peek(): Token {
        curToken
    }

    func bump(): Token {
        if (pos == input.size) {
            return EOI
        }

        let curItem = input[pos]
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
}
