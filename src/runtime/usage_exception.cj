package jian.runtime

/**
 * CLI usage error; `App.run` prints it with usage and returns exit code 2.
 */
public class UsageException <: Exception {
    public init(message: String) {
        super(message)
    }

    /** An option the command does not declare, as written, e.g. `--x`. */
    public static func unknownOption(option: String): UsageException {
        UsageException("unknown option '${option}'")
    }

    /** A required parameter or an option's value is absent; `name` is e.g. `NAME` or `--times`. */
    public static func missingArgument(name: String): UsageException {
        UsageException("missing argument '${name}'")
    }

    /** Invalid value; `expected` names the required type, e.g. `Int64`. */
    public static func invalidValue(option: String, raw: String, expected: String): UsageException {
        UsageException("invalid value '${raw}' for '${option}': expected ${expected}")
    }

    protected override func getClassName(): String {
        "UsageException"
    }
}
