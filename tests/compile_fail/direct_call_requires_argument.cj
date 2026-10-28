// expect-error: missing
package fixture

import jian.*

@JianCommand
func example(value!: String = JianArgument()) {}
func caller() { example() }
