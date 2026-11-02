// expect-error: @JianDerive[JianArgValue] conflicts with an explicit JianArgValue implementation
package fixture

import jian.*

@JianDerive[JianArgValue]
enum Value <: JianArgValue<Value> { | Empty }
