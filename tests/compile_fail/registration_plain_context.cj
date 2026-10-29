// expect-error: mismatched types
package fixture
import jian.*
@JianContext
class Context { public let number: Int64 = 0 }
let app = JianApp()
@JianCommand[app: app]
func bad(number!: Int64 = JianFromContext<Context>()): Unit {}
