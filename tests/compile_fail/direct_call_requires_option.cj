// expect-error: missing
package fixture

import jian.*

@Command
func example(value!: Int64 = Option()) {}
func caller() { example() }
