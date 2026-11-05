package jian.runtime

/**
 * Intentional rejection by an input hook; generated CLI adapters report a usage error.
 */
public class JianInputException <: Exception {
    public init(message: String) { super(message) }
    protected override func getClassName(): String { "JianInputException" }
}
