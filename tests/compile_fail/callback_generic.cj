// expect-error: @JianCallback does not take generic functions
package fixture

import jian.*

@JianCallback
func example<T>(value: T): Unit {}
