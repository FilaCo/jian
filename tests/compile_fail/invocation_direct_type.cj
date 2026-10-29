// expect-error: expected 'Struct-JianInvocation', found 'Struct-String'
package fixture

import jian.*

@JianCallback
func invalid(invocation!: JianInvocation = JianCurrentInvocation()) { JianCallbackResult.Continue }
func direct(): Unit { invalid(invocation: "command") }
