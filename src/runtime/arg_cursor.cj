package jian.runtime

/** Argument emitted by `ArgCursor`. */
public enum Arg {
    /** `--name`; a separate value is read with `nextValue`. */
    | Long(/* name */String)
    /** `--name=value`, including an empty value. */
    | Long(/* name */String, /* value */String)
    /** ASCII short flag, including one split from a cluster. */
    | Short(/* ASCII name */Byte)
    /** ASCII short option with an attached or separate value. */
    | Short(/* ASCII name */Byte, /* value */String)
    /** Non-option argument: a positional, subcommand name, `-`, or anything after `--`. */
    | Operand(String)
}

/**
 * Cursor contract for generated parsers; parsing methods are currently stubs.
 */
public class ArgCursor {
    /** `shortsTakingValue` disambiguates clusters from attached values. */
    public ArgCursor(private let argv: Array<String>, private let shortsTakingValue!: Array<Byte> = []) {}

    /**
     * Returns the next argument without consuming it; `None` at the end.
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
     * Reads the separate value of `--option value`; `option` is used in errors.
     *
     * throws UsageException when no argument is left.
     */
    public func nextValue(option: String): String {
        throw UnsupportedException("ArgCursor.nextValue(${option}): not implemented yet")
    }

    /**
     * Returns unconsumed argv so `App` can forward it to a subcommand unchanged.
     */
    public func remaining(): Array<String> {
        throw UnsupportedException("ArgCursor.remaining: not implemented yet")
    }
}
