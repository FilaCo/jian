package jian.runtime

/**
 * A conversion failure without a parameter name.
 * The command parser adds that context with UsageException.invalidValue.
 */
public class InvalidValueException <: Exception {
    public InvalidValueException(
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
        "InvalidValueException"
    }
}
