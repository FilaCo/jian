package jian.runtime

/**
 * A conversion failure without an argument or option name.
 * The command parser adds that context with JianUsageException.invalidValue.
 */
public class JianInvalidValueException <: Exception {
    public JianInvalidValueException(
        /**
         * The input exactly as supplied.
         */
        public let raw: String,
        /**
         * The expected value type, such as `Int64`.
         */
        public let expected: String
    ) {
        super("invalid value '${raw}': expected ${expected}")
    }

    protected override func getClassName(): String {
        "JianInvalidValueException"
    }
}
