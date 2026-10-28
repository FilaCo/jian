// expect-error: @Command return type must be Unit or Int64
package fixture

import jian.*

@Command
func example(): String { "bad" }
