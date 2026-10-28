// expect-error: short name must be a single ASCII character literal
package fixture

import jian.*

@Command
func example(value!: Bool = Option(short: '\n')) {}
