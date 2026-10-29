// expect-error: duplicate JianCommand setting 'app'
package fixture
import jian.*
let app = JianApp()
@JianCommand[app: app, app: app]
func bad(): Unit {}
