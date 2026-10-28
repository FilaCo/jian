// expect-error: short name '-h' is reserved for help
package fixture

import jian.*

@JianCommand
func example(hidden!: Bool = JianOption(short: 'h')) {}
