// expect-error: JianCallback does not support root
package fixture
import jian.*
let app = JianApp()
@JianCallback[app, root: true]
func bad(): JianCallbackResult { JianCallbackResult.Continue }
