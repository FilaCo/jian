package jian.runtime

/**
 * One argument as `ArgCursor` reads it.
 */
public enum Arg {
    /**
     * `--name`, `--name value` or `--name=value`.
     */
    | Long(/* name */String, /* value */?String)
    /**
     * One ASCII short option: `-n`, `-n=v`, `-nv` or `-n v`.
     * The cursor splits `-abc` into individual options; a value-taking option
     * consumes the rest of the cluster or the next argument.
     */
    | Short(/* ASCII name */Byte, /* value */?String)
    /**
     * `anything`, `-` and everything after `--`.
     */
    | Positional(String)
}

/**
 * Reads a command line one argument at a time: a pure function of `argv` and of which
 * short options take a value (without that, `-tv3` cannot be told from `-t v3`).
 * Short option names are single ASCII bytes, matching `ParamSpec.short`.
 */
public class ArgCursor {
    public ArgCursor(private let argv: Array<String>, private let shortsTakingValue!: Array<Byte> = []) {}

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

    /**
     * The arguments not consumed yet, as given: what `App` hands its subcommand.
     */
    public func remaining(): Array<String> {
        throw UnsupportedException("ArgCursor.remaining: not implemented yet")
    }
}
