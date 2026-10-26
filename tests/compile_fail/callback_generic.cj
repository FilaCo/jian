// expect-error: @Callback does not take generic functions
package fixture

import jian.*

@Callback
func example<T>(value: T): Unit {}
