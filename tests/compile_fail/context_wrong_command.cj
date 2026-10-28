// expect-error: mismatched types
package fixture

import jian.*
@JianContext
class ContextA { public let text: String = "a" }
@JianContext
class ContextB { public let text: String = "b" }
@JianCommand
func bad(text!: String = JianFromContext<ContextB>()): Unit {}
func register(): Unit { JianApp<ContextA>(name: "demo").add(BadCommand()) }
