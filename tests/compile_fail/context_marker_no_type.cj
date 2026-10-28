// expect-error: JianFromContext requires one context type and no arguments
package fixture

import jian.*
@JianContext
class ContextA { public let text: String = "a" }
@JianContext
class ContextB { public let text: String = "b" }
@JianCommand
func bad(text!: String = JianFromContext()): Unit {}
