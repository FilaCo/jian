// expect-error: @JianDerive[JianArgValue] does not support non-exhaustive enums
package fixture
import jian.*
@JianDerive[JianArgValue]
enum Value { | Empty | ... }
