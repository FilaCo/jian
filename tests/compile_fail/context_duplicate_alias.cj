// expect-error: has been implemented
package fixture

import jian.*
type Name = String
@JianContext
class Context { public let first: String = "a"; public let second: Name = "b" }
