// expect-error: cannot convert an integer literal
package fixture

import jian.*

@Command
func example(value!: Int64 = Option(help: 42)) {}
