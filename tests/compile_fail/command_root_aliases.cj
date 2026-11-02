// expect-error: JianCommand root: true does not support name or aliases
package fixture
import jian.*
let app = JianApp()
@JianCommand[app, root: true, aliases: ["files"]]
func bad(): Unit {  }
