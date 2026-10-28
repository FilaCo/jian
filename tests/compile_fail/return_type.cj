// expect-error: @JianCommand return type must be Unit or Int64
package fixture

import jian.*

@JianCommand
func example(): String { "bad" }
