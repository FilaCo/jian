// expect-error: mismatched types
package fixture

import jian.*
@JianContext
class ContextA { public let text: String = "a" }
@JianContext
class ContextB { public let text: String = "b" }
func register(): Unit {
    JianApp<ContextA>(name: "demo").add(JianApp<ContextB>(name: "child"))
}
