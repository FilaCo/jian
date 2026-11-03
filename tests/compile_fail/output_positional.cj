// expect-error: expected ',' or ')', found '='
package fixture

import jian.*

@JianCallback
func invalid(invocation: JianOutput = JianCurrentOutput()) { JianCallbackResult.Continue }
