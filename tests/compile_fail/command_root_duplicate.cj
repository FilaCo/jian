// expect-error: duplicate JianCommand setting 'root'
package fixture
import jian.*
let app = JianApp()
@JianCommand[app, root: true, root: false]
func bad(): Unit {  }
