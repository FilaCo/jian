// expect-error: all JianFromContext parameters must use the same context type
package fixture

import jian.*
@JianContext
class ContextA { public let text: String = "a" }
@JianContext
class ContextB { public let text: String = "b" }
@JianCommand
func bad(a!: String = JianFromContext<ContextA>(), b!: String = JianFromContext<ContextB>()): Unit {}
