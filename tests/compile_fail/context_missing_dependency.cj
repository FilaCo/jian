// expect-error: is not a subtype
package fixture

import jian.*
@JianContext
class ContextA { public let text: String = "a" }
@JianContext
class ContextB { public let text: String = "b" }
@JianCommand
func bad(number!: Int64 = JianFromContext<ContextA>()): Unit {}
