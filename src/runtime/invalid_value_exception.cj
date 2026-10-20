package jian.runtime

/**
 * Invalid CLI value before the parser adds the parameter's name.
 */
public class InvalidValueException <: UsageException {
    /**
     * The input exactly as supplied.
     */
    public let raw: String
    /**
     * The expected value type, such as `Int64`.
     */
    public let expected: String

    public init(raw: String, expected: String) {
        super("invalid value '${raw}': expected ${expected}")
        this.raw = raw
        this.expected = expected
    }

    protected override func getClassName(): String {
        "InvalidValueException"
    }
}
