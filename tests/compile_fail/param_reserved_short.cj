// expect-error: short name '-h' is reserved for help
package fixture

import jian.*

@Command
func example(@Param[short: 'h'] hidden!: Bool) {}
