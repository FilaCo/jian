// expect-error: missing
package fixture

import jian.*

@Command
func example(value!: String = Argument()) {}
func caller() { example() }
