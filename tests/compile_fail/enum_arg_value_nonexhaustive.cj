// expect-error: @JianEnumArgValue does not support non-exhaustive enums
package fixture
import jian.*
@JianEnumArgValue
enum Value { | Empty | ... }
