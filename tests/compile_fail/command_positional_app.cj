// expect-error: JianCommand settings must be named; use app: app
package fixture
import jian.*
let app = JianApp()
@JianCommand[app]
func bad(): Unit {}
