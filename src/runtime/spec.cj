package jian.runtime

import std.deriving.*

/** What help and usage know about a command or a callback: generated as literals. */
public struct CommandSpec {
    public CommandSpec(
        /** The text under the usage line; empty for none. */
        public let help!: String = "",
        /** The parameters, in declaration order. */
        public let params!: Array<ParamSpec> = []
    ) {}
}

/** How a parameter appears on the command line. */
@Derive[Equatable, ToString]
public enum ParamKind {
    | Positional // `NAME`, by position.
    | ValueOption // `--times <INT>`: an option taking a value.
    | Flag // `--loud`: an option taking no value.
}

/** What help and usage know about one parameter of a command. */
public struct ParamSpec {
    public ParamSpec(
        /** The CLI name in kebab case without dashes, e.g. `dry-run`. */
        public let name: String,
        public let kind!: ParamKind,
        /** The placeholder for the value, e.g. `INT` or `INT...`; empty for a flag. */
        public let metavar!: String = "",
        /** The one-letter alias, e.g. `t` for `-t`. */
        public let short!: ?Rune = None,
        /** The text beside the parameter in help; empty for none. */
        public let help!: String = "",
        /** Left out of help. */
        public let hidden!: Bool = false,
        /** The default value as help shows it; `None` to show none. */
        public let defaultShown!: ?String = None,
        /** Absent from the command line is a usage error. */
        public let required!: Bool = false,
        /** May be given more than once, e.g. `--path a --path b`. */
        public let repeatable!: Bool = false
    ) {}
}
