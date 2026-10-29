// expect-error: JianCurrentInvocation is only supported by @JianCallback
package fixture

import jian.*

@JianCommand
func invalid(invocation!: JianInvocation = JianCurrentInvocation()): Unit {}
