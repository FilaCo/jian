// expect-error: JianCommand root: true does not support name or aliases
package fixture
import jian.*
let app = JianApp()
@JianCommand[app, root: true, name: "files"]
func bad(): Unit {  }
