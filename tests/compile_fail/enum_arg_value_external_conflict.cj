// expect-error: has been implemented by 'Enum-Value', please remove it
package fixture
import jian.*
@JianDerive[JianArgValue]
enum Value { | Empty }
extend Value <: JianArgValue<Value> {
    public static func takesValue(): Bool { true }
    public static func metavar(): String { "VALUE" }
    public static func whenAbsent(): ?Value { None }
    public static func accept(_: ?Value, _: ?String): Value { Empty }
}
