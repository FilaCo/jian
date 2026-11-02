// expect-error: @JianDerive requires exactly one supported interface: JianArgValue
package fixture

import jian.*

@JianDerive[JianArgValue, JianArgValue]
enum Value { | Empty }
