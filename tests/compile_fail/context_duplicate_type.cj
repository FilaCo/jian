// expect-error: duplicate context field type
package fixture

import jian.*
@JianContext
class Context { public let first: String = "a"; public let second: String = "b" }
