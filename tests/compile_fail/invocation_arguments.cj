// expect-error: JianCurrentInvocation takes no type arguments or arguments
package fixture

import jian.*

@JianCallback
func invalid(invocation!: JianInvocation = JianCurrentInvocation(1)) { JianCallbackResult.Continue }
