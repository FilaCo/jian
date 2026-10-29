// expect-error: expected 1 argument, found 0
package fixture

import jian.*

@JianCallback
func invalid(invocation!: JianInvocation = JianCurrentInvocation()) { JianCallbackResult.Continue }
func direct(): Unit { invalid() }
