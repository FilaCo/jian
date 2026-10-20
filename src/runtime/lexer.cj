package jian.runtime

import std.deriving.*

class Lexer <: Iterable<Token> {
    private Lexer(
        private let argv: Array<String>,
        private var pos!: Int64 = 0,
        private var cur!: Token = Dummy
    ) {}

    static func make(argv: Array<String>): Lexer {
        let lexer = Lexer(argv)
        let _ = lexer.bump()

        lexer
    }

    public func iterator(): Iterator<Token> {
        TokenIterator(this)
    }

    func peek(): Token {
        cur
    }

    func bump(): Token {
        let tok = argv.get(pos).map {
            s: String => match (s) {
                case "--" => Eoi
                case "-" => stdinPlaceholder()
                case s where s.startsWith("--") => doubleDashed(s)
                case s where s.startsWith("-") => dashed(s)
                case s => value(s)
            }
        } ?? Eoi

        let res = cur
        cur = tok
        res
    }

    func isAtEoi(): Bool {
        pos == argv.size
    }

    func remainder(): Array<String> {
        if (isAtEoi() || argv.size == 0) {
            return []
        }

        if (cur == Eoi) {
            return argv[(pos + 1)..]
        }

        argv[pos - 1..]
    }

    private func stdinPlaceholder(): Token {
        pos++

        StdinPlaceholder
    }

    private func doubleDashed(s: String): Token {
        pos++

        let parts = s.removePrefix("--").split("=", 2)
        if (parts.size > 1) {
            DoubleDashed(parts[0], parts[1])
        } else {
            DoubleDashed(parts[0])
        }
    }

    private func dashed(s: String): Token {
        pos++

        let parts = s.removePrefix("-").split("=", 2)
        if (parts.size > 1) {
            Dashed(parts[0], parts[1])
        } else {
            Dashed(parts[0])
        }
    }

    private func value(s: String): Token {
        pos++

        Value(s)
    }
}

private class TokenIterator <: Iterator<Token> {
    TokenIterator(private let lexer: Lexer) {}

    public func next(): ?Token {
        match (lexer.bump()) {
            case Eoi => None
            case token => Some(token)
        }
    }
}

@Derive[Equatable, ToString]
enum Token {
    // `-`.
    | StdinPlaceholder
    // `-f` or an unresolved cluster such as `-vvv`.
    | Dashed(String)
    // `-f=123`.
    | Dashed(String, String)
    // `--foo`.
    | DoubleDashed(String)
    // `--foo=bar`.
    | DoubleDashed(String, String)
    | Value(String)
    // Also represents `--`; callers recover trailing arguments via `remainder()`.
    | Eoi
    // Initial lookahead before the first `bump()`.
    | Dummy
}
