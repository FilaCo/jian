// expect-error: expected ',' or ')', found '='
package fixture

import jian.*
@JianContext
class ContextA { public let text: String = "a" }
@JianContext
class ContextB { public let text: String = "b" }
@JianCommand
func bad(text: String = JianFromContext<ContextA>()): Unit {}
