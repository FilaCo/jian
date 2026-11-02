// expect-error: @JianEnumArgValue requires variants without associated values
package fixture

import jian.*

@JianEnumArgValue
enum Value { | Empty | Data(Int64) }
