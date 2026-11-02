// expect-error: JianCommand root: true requires a positional app
package fixture
import jian.*
let app = JianApp()
@JianCommand[root: true]
func bad(): Unit {  }
