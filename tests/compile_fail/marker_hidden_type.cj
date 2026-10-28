// expect-error: expected
package fixture

import jian.*

@JianCommand
func example(value!: Int64 = JianArgument(hidden: "yes")) {}
