// expect-error: mismatched types
package fixture
import jian.*
@JianContext
class ContextA { public let number: Int64 = 0 }
@JianContext
class ContextB { public let number: Int64 = 0 }
let app = JianContextApp<ContextA>()
@JianCallback[app: app]
func bad(number!: Int64 = JianFromContext<ContextB>()): Unit {}
