// expect-error: JianCurrentInvocation requires parameter type JianInvocation
package fixture

import jian.*

@JianCallback
func invalid(invocation!: String = JianCurrentInvocation()) { JianCallbackResult.Continue }
