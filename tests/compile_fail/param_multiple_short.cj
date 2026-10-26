// expect-error: short name must be a single ASCII character literal
package fixture

import jian.*

@Command
func example(@Param[short: 'ab'] value!: Bool) {}
