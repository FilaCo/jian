// expect-error: missing argument
package fixture

import jian.*
@JianContext
class ContextA { public let text: String = "a" }
@JianContext
class ContextB { public let text: String = "b" }
func run(): Unit { JianContextApp<ContextA>(name: "demo").run([]) }
