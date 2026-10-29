// expect-error: JianCallback app must be positional
package fixture
import jian.*
let app = JianApp()
@JianCallback[app: app]
func bad(): Unit {}
