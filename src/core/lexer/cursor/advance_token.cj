protected package jian.core.lexer.cursor

extend Cursor {
    static func tokenize(input: String): Iterator<CursorToken> {
        Cursor(input).iterator()
    }

    func iterator(): Iterator<CursorToken> {
        CursorIterator(this)
    }

    mut func advanceToken(): CursorToken {
        let firstByte = bump() ?? return CursorToken.eoi()

        let kind = match (firstByte) {
            case '-' => match (first) {
                case '-' where isAtEoi() || isWhitespace(second) => EOI
                case '-' => doubleDashed()
                case b where isWhitespace(b) => StdinPlaceholder
                case _ => dashed()
            }
            case ' ' => ws()
            case ',' => Comma
            case '=' => Eq
            case _ => value()
        }

        let size = bumpedSize
        resetRemainderSize()

        CursorToken(kind, size)
    }

    private mut func doubleDashed(): CursorTokenKind {
        eatWhile {b => !isWhitespace(b) && b != b'='}
        DoubleDashed
    }

    private mut func dashed(): CursorTokenKind {
        eatWhile {b => !isWhitespace(b) && b != b'='}
        DoubleDashed
    }

    private mut func ws(): CursorTokenKind {
        eatWhile(isWhitespace)
        WS
    }

    private mut func value(): CursorTokenKind {
        eatWhile {b => !isWhitespace(b)}
        Value
    }
}

func isWhitespace(byte: Byte): Bool {
    byte == b' '
}

class CursorIterator <: Iterator<CursorToken> {
    CursorIterator(private var cursor: Cursor) {}

    public func next(): ?CursorToken {
        let token = cursor.advanceToken()
        match (token.kind) {
            case EOI => None
            case _ => Some(token)
        }
    }
}
