// expect-error: JianCurrentOutput requires parameter type JianOutput
package fixture

import jian.*

@JianCallback
func invalid(output!: String = JianCurrentOutput()): JianCallbackResult { JianCallbackResult.Continue }
