// expect-error: 'add' is not a member of struct 'String'
package fixture
import jian.*
let app = "not an app"
@JianCommand[app: app]
func bad(): Unit {}
