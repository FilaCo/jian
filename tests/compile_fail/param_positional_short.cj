// expect-error: short name requires a named parameter
package fixture

import jian.*

@Command
func example(@Param[short: 'v'] value: String) {}
