// expect-error: @JianDerive[JianArgValue] requires a nongeneric enum
package fixture

import jian.*

@JianDerive[JianArgValue]
enum Value<T> { | Empty }
