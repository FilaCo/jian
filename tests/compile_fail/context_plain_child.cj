// expect-error: mismatched types
package fixture
import jian.*
@JianContext
class Context { public let number: Int64 = 0 }
func register(): Unit {
    JianApp().add(JianContextApp<Context>(), name: "child")
}
