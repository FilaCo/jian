// expect-error: @JianContext fields require explicit types
package fixture

import jian.*
@JianContext
class Context { public let value = "text" }
