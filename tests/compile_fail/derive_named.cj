// expect-error: @JianDerive requires exactly one supported interface: JianArgValue
package fixture

import jian.*

@JianDerive[value: JianArgValue]
enum Value { | Empty }
