// expect-error: short name '-h' is reserved for help
package fixture

import jian.*

@Command
func example(hidden!: Bool = Option(short: 'h')) {}
