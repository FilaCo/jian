// expect-error: JianCommand root must be a Bool literal
package fixture
import jian.*
let app = JianApp()
@JianCommand[app, root: 1 == 1]
func bad(): Unit {  }
