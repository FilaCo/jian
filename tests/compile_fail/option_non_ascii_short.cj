// expect-error: short name must be a single ASCII character literal
package fixture

import jian.*

@JianCommand
func example(value!: Bool = JianOption(short: 'я')) {}
