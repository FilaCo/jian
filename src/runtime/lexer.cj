package jian.runtime

import std.deriving.*

class Lexer <: Iterable<Token> {
    private Lexer(
        private let argv: Array<String>,
        private var pos!: Int64 = 0,
        private var cur!: Token = Token.Dummy
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
                case "--" => Token.Eoi
                case "-" => operand(s)
                case s where s.startsWith("--") => longOption(s)
                case s where s.startsWith("-") => shortOption(s)
                case s => operand(s)
            }
        } ?? Token.Eoi

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

        if (cur == Token.Eoi) {
            return argv[(pos + 1)..]
        }

        argv[pos - 1..]
    }

    private func longOption(s: String): Token {
        pos++

        let parts = s.removePrefix("--").split("=", 2)
        if (parts.size > 1) {
            Token.Long(parts[0], parts[1])
        } else {
            Token.Long(parts[0])
        }
    }

    private func shortOption(s: String): Token {
        pos++

        let parts = s.removePrefix("-").split("=", 2)
        if (parts.size > 1) {
            Token.Short(parts[0], parts[1])
        } else {
            Token.Short(parts[0])
        }
    }

    private func operand(s: String): Token {
        pos++

        Token.Operand(s)
    }
}

private class TokenIterator <: Iterator<Token> {
    TokenIterator(private let lexer: Lexer) {}

    public func next(): ?Token {
        match (lexer.bump()) {
            case Token.Eoi => None
            case token => Some(token)
        }
    }
}

@Derive[Equatable, ToString]
enum Token {
    // `-f` or an unresolved cluster such as `-vvv`.
    | Short(String)
    // `-f=123`.
    | Short(String, String)
    // `--foo`.
    | Long(String)
    // `--foo=bar`.
    | Long(String, String)
    | Operand(String)
    // Also represents `--`; callers recover trailing arguments via `remainder()`.
    | Eoi
    // Initial lookahead before the first `bump()`.
    | Dummy
}
