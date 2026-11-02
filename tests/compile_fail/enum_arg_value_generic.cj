// expect-error: @JianEnumArgValue requires a nongeneric enum
package fixture

import jian.*

@JianEnumArgValue
enum Value<T> { | Empty }
