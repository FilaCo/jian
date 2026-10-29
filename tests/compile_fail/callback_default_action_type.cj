// expect-error: should match expected type 'Enum-Option<Struct-String>'
package fixture

import jian.*

@JianCallback[defaultAction: true]
func invalid() { JianCallbackResult.Continue }
