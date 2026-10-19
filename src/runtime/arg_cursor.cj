package jian.runtime

/** One argument as `ArgCursor` reads it. */
public enum Arg {
    | LongOption(String, ?String) // `--name` or `--name=value`: the name without dashes, the value after `=`.
    | ShortOption(Rune, ?String) // `-n`, a letter of a cluster `-abc`; the value if `n` takes one (`-n=v`, `-nv`, `-n v`).
    | Operand(String) // A positional argument: anything else, `-` and everything after `--`.
}

/**
 * Reads a command line one argument at a time: a pure function of `argv` and of which
 * short options take a value (without that, `-tv3` cannot be told from `-t v3`).
 *
 * Part of the macro's API: the generated `Command.run` reads its parameters from it.
 * The bodies come in #12.
 */
public class ArgCursor {
    private let argv: Array<String>
    private let shortsTakingValue: Array<Rune>

    public init(argv: Array<String>, shortsTakingValue!: Array<Rune> = []) {
        this.argv = argv
        this.shortsTakingValue = shortsTakingValue
    }

    /**
     * The next argument without consuming it; `None` at the end.
     *
     * throws UsageException when a short option taking a value has none.
     */
    public func peek(): ?Arg {
        throw UnsupportedException("ArgCursor.peek: not implemented yet")
    }

    /**
     * Consumes the next argument; `None` at the end.
     *
     * throws UsageException when a short option taking a value has none.
     */
    public func next(): ?Arg {
        throw UnsupportedException("ArgCursor.next: not implemented yet")
    }

    /**
     * Consumes the value of a long option given as `--option value`; `option` names it in errors.
     *
     * throws UsageException when no argument is left.
     */
    public func nextValue(option: String): String {
        throw UnsupportedException("ArgCursor.nextValue(${option}): not implemented yet")
    }

    /** The arguments not consumed yet, as given: what `App` hands its subcommand. */
    public func remaining(): Array<String> {
        throw UnsupportedException("ArgCursor.remaining: not implemented yet")
    }
}
