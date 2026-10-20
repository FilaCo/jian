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

/** Traverses argv, splitting short options using their declared value requirements. */
public class ArgCursor {
    private var position: Int64 = 0
    private var shortOffset: Int64 = 0
    private var optionsEnded: Bool = false

    /** `shortsTakingValue` contains ASCII names whose suffix or following argv is their value. */
    public ArgCursor(private let argv: Array<String>, private let shortsTakingValue!: Array<Byte> = []) {}

    /**
     * Returns the next argument without consuming it; None at EOF.
     * throws UsageException for a missing value or non-ASCII short name.
     */
    public func peek(): ?Arg {
        let (arg, _, _, _) = read()
        arg
    }

    /**
     * Consumes one argument; returns None at EOF.
     * throws UsageException for a missing value or non-ASCII short name.
     */
    public func next(): ?Arg {
        let (arg, nextPosition, nextOffset, ended) = read()
        position = nextPosition
        shortOffset = nextOffset
        optionsEnded = ended
        arg
    }

    /**
     * Consumes the next raw argv, even `--` or option-looking text, as a required value.
     * Within a partial cluster, consumes its reconstructed `-suffix` instead.
     * throws UsageException naming `option` when no input remains.
     */
    public func nextValue(option: String): String {
        if (position == argv.size) {
            throw UsageException.missingArgument(option)
        }
        let value = if (shortOffset == 0) { argv[position] } else { "-" + argv[position][shortOffset..] }
        position++
        shortOffset = 0
        value
    }

    /**
     * Copies unconsumed argv for subcommand dispatch without changing the cursor.
     * Raw strings, including `--`, are preserved at argv boundaries. Within a
     * cluster, the first string is `-` plus its unconsumed suffix.
     */
    public func remaining(): Array<String> {
        let result = argv[position..].clone()
        if (shortOffset != 0) {
            result[0] = "-" + argv[position][shortOffset..]
        }
        result
    }

    // Compute the next state without committing it: lookahead cannot classify a
    // required raw value irreversibly, nor consume a marker or part of a cluster.
    private func read(): (?Arg, Int64, Int64, Bool) {
        var index = position
        var ended = optionsEnded
        while (index < argv.size) {
            let raw = argv[index]
            if (ended || raw == "-" || !raw.startsWith("-")) {
                return (Some(Arg.Operand(raw)), index + 1, 0, ended)
            }
            if (raw == "--") {
                ended = true
                index++
                continue
            }
            if (raw.startsWith("--")) {
                let parts = raw[2..].split("=", 2)
                let arg = if (parts.size == 2) { Arg.Long(parts[0], parts[1]) } else { Arg.Long(parts[0]) }
                return (Some(arg), index + 1, 0, ended)
            }
            let offset = if (shortOffset == 0) { 1 } else { shortOffset }
            let name = raw.toArray()[offset]
            if (name > 127) {
                throw UsageException.unknownOption("-" + raw[offset..])
            }
            if (shortsTakingValue.contains(name)) {
                let suffix = raw[offset + 1..]
                if (!suffix.isEmpty()) {
                    let value = if (suffix.startsWith("=")) { suffix[1..] } else { suffix }
                    return (Some(Arg.Short(name, value)), index + 1, 0, ended)
                }
                if (index + 1 == argv.size) {
                    throw UsageException.missingArgument("-" + raw[offset..])
                }
                return (Some(Arg.Short(name, argv[index + 1])), index + 2, 0, ended)
            }
            // `-o=value` is explicit even if the caller does not declare o as
            // value-taking; generated parsers decide whether that form is valid.
            if (offset + 1 < raw.size && raw[offset + 1..].startsWith("=")) {
                return (Some(Arg.Short(name, raw[offset + 2..])), index + 1, 0, ended)
            }
            if (offset + 1 == raw.size) {
                return (Some(Arg.Short(name)), index + 1, 0, ended)
            }
            return (Some(Arg.Short(name)), index, offset + 1, ended)
        }
        (None, index, 0, ended)
    }
}
