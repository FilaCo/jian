protected package jian.core.lexer.cursor

protected struct Cursor {
    private static const EOF_CHAR = b'\0'
    private var remainderSize: Int64

    protected Cursor(private var input: String) {
        remainderSize = input.size
    }

    prop bumpedSize: Int64 {
        get() {
            remainderSize - input.size
        }
    }

    prop first: Byte {
        get() {
            input.get(0).getOrDefault {=> EOF_CHAR}
        }
    }

    prop second: Byte {
        get() {
            input.get(1).getOrDefault {=> EOF_CHAR}
        }
    }

    mut func bump(): ?Byte {
        let res = input.get(0)
        if (input.size > 0) {
            input = input[1..]
        }
        res
    }

    mut func eatWhile(predicate: (Byte) -> Bool) {
        while (predicate(first) && !isAtEoi()) {
            bump()
        }
    }

    mut func resetRemainderSize(): Unit {
        remainderSize = input.size
    }

    func isAtEoi(): Bool {
        input.isEmpty()
    }
}
