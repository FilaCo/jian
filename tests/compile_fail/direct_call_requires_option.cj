// expect-error: missing
package fixture

import jian.*

@JianCommand
func example(value!: Int64 = JianOption()) {}
func caller() { example.call() }
