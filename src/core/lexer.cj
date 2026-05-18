protected package jian.core

import std.deriving.*

struct Lexer <: Iterable<Token> {
    private var pos = 0
    private var cur = Dummy
    private Lexer(private let argv: Array<String>) {}

    static func make(argv: Array<String>): Lexer {
        var lexer = Lexer(argv)
        let _ = lexer.bump()

        lexer
    }

    public func iterator(): Iterator<Token> {
        TokenIterator(this)
    }

    func peek(): Token {
        cur
    }

    mut func bump(): Token {
        if (pos > argv.size) {
            return cur
        }

        if (pos == argv.size) {
            pos++
            let res = cur
            cur = EOI
            return res
        }

        let tok = match (argv[pos]) {
            case "--" => EOI
            case "-" => StdinPlaceholder
            case s where s.startsWith("--") => doubleDashed(s)
            case s where s.startsWith("-") => dashed(s)
            case s => Value(s)
        }

        pos++
        let res = cur
        cur = tok
        res
    }

    private func doubleDashed(s: String): Token {
        let parts = s.split("=", 2)
        if (parts.size > 1) {
            DoubleDashed(parts[0], parts[1])
        } else {
            DoubleDashed(parts[0])
        }
    }

    private func dashed(s: String): Token {
        let parts = s.split("=", 2)
        if (parts.size > 1) {
            Dashed(parts[0], parts[1])
        } else {
            Dashed(parts[0])
        }
    }
}

class TokenIterator <: Iterator<Token> {
    TokenIterator(private var lexer: Lexer) {}

    public func next(): ?Token {
        match (lexer.bump()) {
            case EOI => None
            case token => Some(token)
        }
    }
}

@Derive[Equatable, ToString]
enum Token {
    | StdinPlaceholder
    | Dashed(String)
    | Dashed(String, String)
    | DoubleDashed(String)
    | DoubleDashed(String, String)
    | Value(String)
    | EOI
    | Dummy
}
