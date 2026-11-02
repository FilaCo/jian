// expect-error: @JianDerive[JianArgValue] requires variants without associated values
package fixture

import jian.*

@JianDerive[JianArgValue]
enum Value { | Empty | Data(Int64) }
