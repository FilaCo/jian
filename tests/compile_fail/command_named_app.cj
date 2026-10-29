// expect-error: JianCommand app must be positional
package fixture
import jian.*
let app = JianApp()
@JianCommand[app: app]
func bad(): Unit {}
