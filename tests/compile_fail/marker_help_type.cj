// expect-error: cannot convert an integer literal
package fixture

import jian.*

@JianCommand
func example(value!: Int64 = JianOption(help: 42)) {}
