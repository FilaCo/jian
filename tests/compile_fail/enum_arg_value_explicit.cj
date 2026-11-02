// expect-error: @JianEnumArgValue conflicts with an explicit JianArgValue implementation
package fixture

import jian.*

@JianEnumArgValue
enum Value <: JianArgValue<Value> { | Empty }
