package jian.runtime

import std.deriving.*

/**
 * Command or callback metadata used to render help and usage.
 */
public struct JianCommandSpec {
    public JianCommandSpec(
        /**
         * The text under the usage line; empty for none.
         */
        public let help!: String = "",
        /**
         * Arguments and options, in declaration order.
         */
        public let inputs!: Array<JianInputSpec> = []
    ) {}
}

/**
 * Whether a CLI input is a positional argument, value option or flag.
 */
@Derive[Equatable, ToString]
public enum JianInputKind {
    /**
     * `NAME`, by position.
     */
    | Positional
    /**
     * `--times <INT>`: an option taking a value.
     */
    | ValueOption
    /**
     * `--loud`: an option taking no value.
     */
    | Flag
}

/**
 * Argument or option metadata used to render help and usage.
 */
public struct JianInputSpec {
    public JianInputSpec(
        /**
         * The CLI name in kebab case without dashes, e.g. `dry-run`.
         */
        public let name: String,
        public let kind!: JianInputKind,
        /**
         * The placeholder for the value, e.g. `INT` or `INT...`; empty for a flag.
         */
        public let metavar!: String = "",
        /**
         * The single ASCII alias, e.g. `b't'` for `-t`.
         */
        public let short!: ?Byte = None,
        /**
         * The text beside the argument or option in help; empty for none.
         */
        public let help!: String = "",
        /**
         * Left out of help.
         */
        public let hidden!: Bool = false,
        /**
         * The default value as help shows it; `None` to show none.
         */
        public let defaultShown!: ?String = None,
        /**
         * Absent from the command line is a usage error.
         */
        public let required!: Bool = false,
        /**
         * May be given more than once, e.g. `--path a --path b`.
         */
        public let repeatable!: Bool = false
    ) {}
}
