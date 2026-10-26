// expect-error: @Callback return type must be Unit or Int64
package fixture

import jian.*

@Callback
func example(): String { "bad" }
