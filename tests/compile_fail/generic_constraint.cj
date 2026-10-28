// expect-error: @Command does not take generic functions
package fixture

import jian.*

@Command
func example<T>(value: T): Unit where T <: ToString {}
