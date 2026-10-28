// expect-error: @JianCallback return type must be Unit or Int64
package fixture

import jian.*

@JianCallback
func example(): String { "bad" }
