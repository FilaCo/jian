// expect-error: @JianCommand does not take generic functions
package fixture

import jian.*

@JianCommand
func example<T>(value: T): Unit where T <: ToString {}
